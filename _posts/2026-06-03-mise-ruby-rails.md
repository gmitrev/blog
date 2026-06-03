---
layout: post
title: Managing Ruby versions with Mise
date: 2026-06-03 18:10 +0300
---

I've been using [chruby](https://github.com/postmodern/chruby) for years now but one thing I've
always disliked is having to compile Ruby when installing new versions. This is now not needed when
using [mise](https://mise.jdx.dev/lang/ruby.html#precompiled-binaries), which can just download
precompiled Ruby binaries on some platforms.

## What is mise

`mise` is a tool to manage runtime versions in your projects. Instead of using `chruby` and `nvm` to
manage Ruby and Node, we can just use `mise` for both. It has other features as well but these are
not important right now. Read the docs for [installation instructions](https://mise.jdx.dev/getting-started.html).

After installing, disable the `ruby.compile` setting:

```bash
mise settings ruby.compile=false # This will soon be default
```

This tells `mise` to download a precompiled version if available. If not,
[ruby-build](https://github.com/rbenv/ruby-build) will be used to compile the desired Ruby version.

## How to set it up in Ruby projects

`mise` can be used without meddling with your PATH by just invoking it directly:

```bash
mise exec ruby@3.4.5 -- ruby -v
```

This will install Ruby 3.4.5 if not installed and will invoke `ruby -v`.

Using `mise exec` every time would be rather annoying and `mise` can be configured to automatically
activate in interactive shells:

```
mise activate
```

This produces a shell script that you can [put in `.bashrc` or
`.zshrc`](https://mise.jdx.dev/getting-started.html#activate-mise) and new shells will now
automatically activate whatever tools you need:

```bash
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
```

If you have an existing `~/.tool-versions` file, `mise use` will by default set the global version
there. In order to scope the version to the current project, pass the `--path` option:

```bash
mise use --path mise.toml ruby@3.4.5 node@24
```

This will install both Ruby 3.4.5 and Node 24. It will also create the `mise.toml` file:

```toml
[tools]
node = "24"
ruby = "3.4.5"
```

Make sure to commit this file.

This is all you need for now. Remember to remove your previous version managers to avoid conflicts.
Also, it's a good idea to remove `node_modules` and install gems again.

## Setting a global version

Use the `--global` (`-g`) flag to set a global version:

```bash
mise use -g ruby@4.0.5
```
