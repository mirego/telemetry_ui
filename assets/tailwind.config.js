module.exports = {
  darkMode: 'class',
  content: ['./js/**/*.ts', '../lib/telemetry_ui/web/**/*.*ex'],
  safelist: [
    {
      pattern: /gap-\w+/,
      variants: ['sm', 'lg']
    },
    {
      pattern: /inline/,
      variants: ['sm', 'lg']
    },
    {
      pattern: /block/,
      variants: ['sm', 'lg']
    },
    {
      pattern: /shadow/,
      variants: ['sm', 'lg']
    },
    {
      pattern: /shadow-\w+/,
      variants: ['sm', 'lg']
    },
    {
      pattern: /grid-cols-\w+/,
      variants: ['sm', 'lg']
    },
    {
      pattern: /(col|row)-(start|end|span)-\w+/,
      variants: ['sm', 'lg']
    },
    {
      pattern: /(col|row)-auto/,
      variants: ['sm', 'lg']
    }
  ],
  plugins: [require('@tailwindcss/forms')]
};
