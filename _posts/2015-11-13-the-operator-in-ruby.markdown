---
layout: post
title: The Safe Navigation Operator (&.) in Ruby
summary: Ruby 2.3 introduces the &. operator which will make dealing with nils easier
date: 2015-11-13
published: true
categories: ruby
---

The most interesting addition to Ruby 2.3.0 is the Safe Navigation Operator(`&.`). A similar
operator has been present in C# and Groovy for a long time with a slightly different syntax - `?.`.
So what does it do?

#### TLDR

It is used for avoiding `NoMethodError` exceptions when calling methods on objects that *may* be
`nil`.

```rb
account = nil

account.number
# => NoMethodError (undefined method `number' for nil:NilClass)`)

account&.number
# => nil
```

## Example

Imagine you have an `account` that has an `owner` and you want to get the `owner`'s `address`. If
you want to be safe and not risk a `nil` error, you would write something like the following:

```rb
if account && account.owner && account.owner.address
...
end
```

This is really verbose and annoying to type. ActiveSupport includes the `try` method which has a
similar behaviour (but with few key differences that will be discussed later):

```rb
if account.try(:owner).try(:address)
...
end
```

It accomplishes the same thing - it either returns the address or `nil` if some value along the
chain is `nil`. The first example may also return `false` if, for example, the `owner` is set to
`false`.

## Using the safe navigation operator (&.)

We can rewrite the previous example using the safe navigation operator:

```rb
account&.owner&.address
```

The syntax is a bit awkward but I guess we will have to deal with it because it does make the code
more compact.

### More examples

Let's compare all three approaches in more detail.

```rb
account = Account.new(owner: nil) # account without an owner

account.owner.address
# => NoMethodError: undefined method `address' for nil:NilClass

account && account.owner && account.owner.address
# => nil

account.try(:owner).try(:address)
# => nil

account&.owner&.address
# => nil
```

No surprises so far. What if `owner` is `false` (unlikely but not impossible in the exciting world
of shitty code)?

```rb
account = Account.new(owner: false)

account.owner.address
# => NoMethodError: undefined method `address' for false:FalseClass j

account && account.owner && account.owner.address
# => false

account.try(:owner).try(:address)
# => nil

account&.owner&.address
# => undefined method `address' for false:FalseClass`
```

Here comes the first surprise - the `&.` syntax only skips `nil` but recognizes `false`! It is not
exactly equivalent to the `s1 && s1.s2 && s1.s2.s3` syntax.

What if the owner is present but doesn't respond to `address`?

```rb
account = Account.new(owner: Object.new)

account.owner.address
# => NoMethodError: undefined method `address' for #<Object:0x00559996b5bde8>

account && account.owner && account.owner.address
# => NoMethodError: undefined method `address' for #<Object:0x00559996b5bde8>`

account.try(:owner).try(:address)
# => nil

account&.owner&.address
# => NoMethodError: undefined method `address' for #<Object:0x00559996b5bde8>`
```

Oops, the `try` method doesn't check if the receiver responds to the given method. This is why
it's always better to use the stricter version of `try` - `try!`:

```rb
account.try!(:owner).try!(:address)
# => NoMethodError: undefined method `address' for #<Object:0x00559996b5bde8>`
```

## Bonus 2.3 features - Array#dig and Hash#dig

The `#dig` method is probably the most useful feature in this version. No longer do we have to
write abominations like the following:

```rb
address = params[:account].try(:[], :owner).try(:[], :address)

# or

address = params[:account].fetch(:owner) { {} }.fetch(:address)
```

We can now simply use `Hash#dig` and accomplish the same thing:

```rb
address = params.dig(:account, :owner, :address)
```

<div class="border border-pink-200 p-4 pt-2 bg-rose-50 rounded text-sm">
  <div class="text-pink-300  text-center mb-2" style="font-size: 8px">
    <span class="text-rose-500 font-bold">[</span>
    shameless plug
    <span class="text-rose-500 font-bold">]</span>
  </div>
  Psst. Check out my latest project, <a class="text-sm" href="https://stonksfolio.com"
    target="_blank">Stonksfolio</a>, if you need an awesome portfolio tracker!
</div>
