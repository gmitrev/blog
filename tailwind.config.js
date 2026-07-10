module.exports = {
  content: [
    './_drafts/**/*.html',
    './_includes/**/*.html',
    './_layouts/**/*.html',
    './_posts/*.md',
    './_posts/*.markdown',
    './*.md',
    './*.html',
  ],
  theme: {
    fontFamily: {
      heading: ['Bitter', 'Georgia', 'Cambria', '"Times New Roman"', 'serif'],
      sans: ['Seravek', '"Gill Sans Nova"', 'Ubuntu', 'Calibri', '"DejaVu Sans"', 'source-sans-pro', 'sans-serif'],
      monospace: ['"IBM Plex Mono"', 'ui-monospace', '"Cascadia Code"', '"Source Code Pro"', 'Menlo', 'Consolas', '"DejaVu Sans Mono"', 'monospace']
    },
    extend: {
      colors: {
        cream: "#FFF1DE",
        purplish: "#F7DCEC",
        olive: "#73956F",
        viridian: "#53917E"
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],
}
