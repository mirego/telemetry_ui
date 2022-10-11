import vegaEmbed from 'vega-embed';

if (
  localStorage.theme === 'dark' ||
  (!('theme' in localStorage) &&
    window.matchMedia('(prefers-color-scheme: dark)').matches)
) {
  document.documentElement.classList.add('dark');
} else {
  document.documentElement.classList.remove('dark');
}

window.drawChart = (id, spec) =>
  vegaEmbed(id, spec, {actions: false}).then(({view}) => {
    const chart = document.querySelector(id);
    const source = view.data('source');

    if (source.length === 0) {
      const element = document.querySelector(id + '-empty');
      element.classList.remove('hidden');
      chart.remove();
    } else {
      chart.classList.remove('hidden');
      const legend = document.querySelector(id + '-legend');

      if (legend && view._runtime.scales.color) {
        legend.classList.remove('hidden');
        const colors = view.scale('color').range();
        const categories = view.scale('color').domain();

        legend.innerHTML = categories
          .sort((a, b) => (parseInt(a) || a) - (parseInt(b) || b))
          .map((category, i) => {
            const colorIndex =
              i - colors.length * Math.floor(i / colors.length);
            const color = colors[colorIndex];

            return `<span class="shrink-0 px-2 py-1 inline-block rounded-sm border-[1px] border-zinc-300 dark:border-zinc-800">
            <span class="inline-block rounded-full h-[10px] w-[10px]" style="background: ${color};"></span>
            ${category}
          </span>`;
          })
          .join('\n');
      }
    }
  });

document.addEventListener('DOMContentLoaded', () => {
  document
    .querySelectorAll('[telemetry-component="ThemeSwitch"]')
    .forEach((themeSwitch) => {
      themeSwitch.addEventListener('click', (event) => {
        event.preventDefault();

        if (localStorage.theme === 'dark') {
          document.documentElement.classList.remove('dark');
          localStorage.theme = 'light';
        } else {
          document.documentElement.classList.add('dark');
          localStorage.theme = 'dark';
        }
      });
    });

  document
    .querySelectorAll('[telemetry-component="LocalTime"]')
    .forEach((time) => {
      const OPTIONS = {
        dateStyle: 'long',
        timeStyle: 'short'
      };
      const dateTimeFormat = new Intl.DateTimeFormat('en-US', OPTIONS);
      const title = time.getAttribute('title');
      if (!title) return;

      time.innerHTML = dateTimeFormat.format(new Date(title));
    });

  document.querySelectorAll('[telemetry-component="Form"]').forEach((form) => {
    form.querySelectorAll('input, select').forEach((input) => {
      input.addEventListener('change', () => form.submit());
    });
  });
});
