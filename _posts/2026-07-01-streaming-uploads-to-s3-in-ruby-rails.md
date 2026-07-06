---
layout: post
title: Streaming uploads to S3 in Ruby/Rails
date: 2026-07-01 18:16 +0300
categories: ruby
published: false
---

When I started working on `noop-backup`, I wanted to make the process of backing up a PostgreSQL
database as frictionless as possible. In my vision, all you had to do was execute `bundle add
noop-backup`, provide an S3 bucket and AWS credentials and maybe setup a slack webhook. Backups
would then be executed in a background worker or manually with a cron.

This means that, ideally, the executor would not dump a huge database on the filesystem where it
happens to run - databases tend to be pretty large and this can cause a lot of issues. Instead of
dumping the database and then uploading it to S3 and then deleting it, I decided to look into a
different way of doing it - streaming directly from `pg_dump` into `S3` without touching the disk
at all.

### Naive implementation

The input in our example will come out of `pg_dump`:

```sh
pg_dump database_name
```

This just dumps out the database to `stdout`. We can capture it in Ruby by using the `Open3`
module:

```rb
require 'open3'

stdin, pg_dump_out = Open3.popen2('pg_dump db_name')
```

`stdin` and `pg_dump_out` are instances of the [`IO`
class](https://docs.ruby-lang.org/en/master/IO.html), which implements input/output streams on the
operating system level. If you've used the [`File`](https://docs.ruby-lang.org/en/master/File.html)
class, you should be familiar with `IO` as `File` is based on it.

Now that we have captured the pg_dump output stream, we need to redirect it to S3. Using the
official AWS SDK for Ruby, this is fairly easy. First, we need to build an `S3::Client` object:

```rb
require "aws-sdk-s3"

client = Aws::S3::Client.new(
  region:            'eu-west-1',
  access_key_id:     ENV.fetch("AWS_ACCESS_KEY_ID"),
  secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY")
)
```

We'll then use the [`TransferManager` class](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/TransferManager.html) to upload the stream.

<div class='note' markdown="1">
In older SDK versions, we'd actually use [`Aws::S3::Object#upload_stream` ](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#upload_stream-instance_method), and you'll see most guides use this. This method is, however, deprecated in the latest SDK and it is recommended to use `TransferManager`.
</div>

We'll use
[`Aws::S3::TransferManager#upload_stream`](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/TransferManager.html#upload_stream-instance_method)
to get an `IO` stream for writing to S3 and then we'll use
[`IO.copy_stream`](https://docs.ruby-lang.org/en/master/IO.html#method-c-copy_stream) to do the
actual copying. `IO.copy_stream` returns the number of bytes written, if this is needed.

```rb
client = Aws::S3::Client.new(...)
transfer_manager = Aws::S3::TransferManager.new(client:)

stdin, pg_dump_out = Open3.popen2('pg_dump db_name')

transfer_manager.upload_stream(bucket: 'bucket-name', key: '2026/06/06.dump') do |s3_stream|
  IO.copy_stream(pg_dump_out, s3_stream)
end
```

This will work but it has several issues. For one, if `pg_dump` fails midway, we'll end up
uploading a corrupted file without knowing it has been corrupted.

### Gotcha 1 - checking for errors

`Open3.popen2` actually returns three objects: the two streams and a wait thread. We can probe the
wait thread to check the exit code of the command:

```rb
stdin, pg_dump_out, wait_thread = Open3.popen2('pg_dump db_name')
stdin.close

IO.copy_stream(pg_dump_out, File::NULL) # pg_dump sleeps until its output is consumed
# Without consuming the output, the code below will hang forever

wait_thread.class          # => Process::Waiter
wait_thread.value          # => #<Process::Status: pid 41357 exit 0>
wait_thread.value.success? # => true
```

If the exit code is not success, make sure to clean up any partially uploaded files.

### Gotcha 2 - forgetting to close input stream

If you forget to call `stdin.close`, the fd will leak and can potentially stay alive for a long
time (until a GC cycle or process exit). `pg_dump` never reads stdin, so here the unclosed pipe is
only a leaked fd. But for a child that reads stdin (e.g. `psql` when you stream a restore), a
forgotten `stdin.close` means it waits for EOF forever.

A possible solution is to use `popen2` with a block. After the block executes, all streams are closed:

```rb
Open3.popen2('pg_dump db_name') do |stdin, pg_dump_out, wait_thread|
  IO.copy_stream(pg_dump_out, File::NULL)

  raise unless wait_thread.value.success?
end
```

### Gotcha 3 - handling stderr

One drawback of `popen2` is that it doesn't yield access to `stderr`. We can use `popen2e` but it
merges `stderr` and `stdout`. As a result, any potential warnings would be added to the database dump. Oops.
Alternatively, we could use `popen3` which yields `stderr` as a standalone object:

```rb
Open3.popen3('pg_dump db_name') do |stdin, stdout, stderr, wait_thread|
  transfer_manager.upload_stream(bucket:, key:) do |s3_stream|
    IO.copy_stream(stdout, s3_stream)
  end

  raise "pg_dump failed: #{stderr.read}" unless wait_thread.value.success?
end
```

This snippet suffers from a fatal flaw - a deadlock. We now have two pipes and one main thread, and
`pg_dump` is writing into both pipes at the same time. Each pipe's buffer is ~64 KB and if
`stderr`'s buffer fills before the `IO.copy_stream` command completes, `pg_dump` will block until
`stderr` is consumed, but this doesn't happen until we finish uploading.

What we can do is consume `stderr` in a new thread so we can avoid a deadlock:

```rb
Open3.popen3('pg_dump db_name') do |stdin, stdout, stderr, wait_thread|
  error_thread = Thread.new { stderr.read }

  transfer_manager.upload_stream(bucket:, key:) do |s3_stream|
    IO.copy_stream(stdout, s3_stream)
  end

  raise "pg_dump failed: #{error_thread.value}" unless wait_thread.value.success?
end
```

### Gotcha 4 - AWS S3 and multipart upload limits

Looking at the documentation for
[`upload_stream`](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/TransferManager.html#upload_stream-instance_method)
reveals two options that are crucial when using this for large files:

`part_size` - default 5MiB (5 * 1024 * 1024) - This directly caps the maximum size of the
uploaded file because [S3 supports maximum 10 000 parts per
upload](https://docs.aws.amazon.com/AmazonS3/latest/userguide/qfacts.html). With the default part
size, we could upload a file up to 48.8 GiB. After the 10000th part, S3 will simply reject further
`UploadPart` calls and the upload will fail. Max `part_size` is `5 GiB` which caps the actual max
file size to `48.8 TiB`.

`thread_count` - default 10 - Number of parallel multipart uploads. Directly contributes to memory
usage. Peak memory is roughly `thread_count` * `part_size`. For the default (10 threads x 5MB)
expect around 50-60MB memory usage.

### Full example

With all gotchas taken into account, this is what the complete code looks like:

```rb
require 'open3'
require 'aws-sdk-s3'

bucket = 'bucket-name'
key = '2026/06/06.dump'
client = Aws::S3::Client.new(...)
transfer_manager = Aws::S3::TransferManager.new(client:)

Open3.popen3('pg_dump db_name') do |_, stdout, stderr, wait_thread|
  error_thread = Thread.new { stderr.read }
  bytes = 0

  transfer_manager.upload_stream(bucket:, key:, part_size: 128 * 1024 * 1024, thread_count: 4) do |s3_stream|
    bytes = IO.copy_stream(stdout, s3_stream)
  end

  raise CustomError, "pg_dump failed: #{error_thread.value}" unless wait_thread.value.success?

  puts "Uploaded #{key} to #{bucket}. Final size: #{bytes}b"
rescue CustomError => e
  client.delete_object(bucket:, key:)
  # possibly re-raise or alert
end
```

### Advanced: progress reporting

With big files, it can take a while until they are uploaded. This is why having a simple progress
indicator goes a long way. I like using [`pv`](https://linux.die.net/man/1/pv) in similar
situations. Output can be piped into it and it will pipe it out while providing some visibility
into the progress:

```sh
pg_dump large_database | pv -btra > dump.sql
# => 1.46GiB 0:00:15 [99.2MiB/s] (99.2MiB/s)
```

This is a bit awkward to do with just `popen3` but we can use another method provided by `Open3` -
[`pipeline_r`](https://docs.ruby-lang.org/en/master/Open3.html#method-i-pipeline_r). This is the
bigger brother of [`pipeline`](https://docs.ruby-lang.org/en/master/Open3.html#method-i-pipeline),
which receives a list of command and pipes them similar the shell example above. `pipeline` returns
an array with the process status objects of each command in the list and prints everything to stdout:

```rb
statuses = Open3.pipeline('ls', 'grep R')
statuses.map(&:success?)
# => [true, true]
```

`pipeline_r` also yields the captured stdout of the last command in the list:

```rb
Open3.pipeline_r('ls', 'grep R') do |last_stdout, wait_threads|
  puts last_stdout.read
end
# => Rakefile
# => README.md
```

We can use it to pipe `pg_dump` into `pv`:

```rb
commands = [
  ["pg_dump", "db_name"],
  ["pv", "-btra"]
]

Open3.pipeline_r(*commands) do |dump_out, wait_threads|
  transfer_manager.upload_stream(bucket:, key:) do |s3_stream|
    IO.copy_stream(dump_out, s3_stream)
  end

  raise "pipeline failed" unless wait_threads.all? { |t| t.value.success? }
end
```

The result will be the same but we'll get a nice looking progress indicator while the file is being
uploaded.

This approach is also very useful if, for example, we want to encrypt the file with `openssl`
before upload.


