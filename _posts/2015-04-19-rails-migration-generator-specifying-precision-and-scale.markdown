---
layout: post
title: Rails migration generator - how to specify decimal precision and scale
summary:
date: 2015-04-19
published: true
categories: rails
---

This is a simple thing to forget and this is why it deserves its own post!

The standard way to do it is:

```sh
rails g migration add_amount_to_records amount:decimal{5,2}
```

But this does not work if you are using `zsh` and instead we get the following migration:

```rb
class AddAmountToRecords < ActiveRecord::Migration[5.2]
  def change
    add_column :records, :amount, :decimal5
    add_column :records, :amount, :decimal2
  end
end
```

We obviously didn't want this. In order to get what we wanted, we can replace the comma with a
hyphen:

```sh
rails g migration add_amount_to_records amount:decimal{5-2}
```

Or simply quote the column declaration:

```sh
rails g migration add_amount_to_records 'amount:decimal{5,2}'
```

Both commands result in the following migration:

```rb
class AddAmountToRecords < ActiveRecord::Migration[5.2]
  def change
    add_column :records, :amount, :decimal, precision: 5, scale: 2
  end
end
```

Bingo!

<div class="border border-pink-200 p-4 pt-2 bg-rose-50 rounded text-sm">
  <div class="text-pink-300  text-center mb-2" style="font-size: 8px">
    <span class="text-rose-500 font-bold">[</span>
    shameless plug
    <span class="text-rose-500 font-bold">]</span>
  </div>
  Psst. Check out my latest project, <a class="text-sm" href="https://stonksfolio.com"
    target="_blank">Stonksfolio</a>, if you need an awesome portfolio tracker!
</div>
