---
layout: post
title: Simple lightbox with just a little JS and CSS
description: "An image lightbox built with the dialog element and a few lines of JavaScript instead of a library."
date: 2026-06-04 00:46 +0300
---

The <a href="/projects" target="_blank">/projects</a> page includes screenshots of my projects but
clicking them used to simply redirect to the project URL. This has always bugged me, but I didn't
want to add a dedicated lightbox library as I hate adding unnecessary libraries to projects.

I figured there must be an easy way to do it with just CSS + simple JS and it turns out, there is!

### &lt;<span class="font-monospace">dialog</span>&gt;

The first part of the puzzle is the [`<dialog>`](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dialog) element.

```html
<dialog>
  <h1>This is my modal</h1>
</dialog>
```

It's used to represent modals and non-modal dialog boxes, which is exactly what we need.
