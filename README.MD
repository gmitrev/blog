# About
The source of my [personal blog](http://mitrev.net).

## Technologies used
* [Jekyll](http://jekyllrb.com/) - Engine

## Running

Install gems and then run:

```ruby
bundle exec jekyll serve --livereload
```

## Create a new post

```sh
jekyll compose "Title for blog post"
```

## Syntax highlighting theme

Code blocks are highlighted by [Rouge](https://github.com/rouge-ruby/rouge). Each
theme lives in its own file under `assets/css/` (e.g. `zenburn.css`), and the
active one is selected by the `@import` line at the top of `main.css`.

List available themes:

```sh
bundle exec rougify list
```

Generate a theme into its own file, scoped to `.highlight`:

```sh
bundle exec rougify style gruvbox.dark --scope ".highlight" > assets/css/gruvbox.css
```

Then point `main.css` at it:

```css
@import "gruvbox.css";
```

Append `.light` or `.dark` to pick a mode (e.g. `github.dark`). Always generate
with `rougify` rather than copying CSS from the web, so selectors are correctly
scoped to `.highlight`.
