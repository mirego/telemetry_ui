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
    if (view.data('source').length === 0) {
      const element = document.querySelector(id + '-empty');
      const chart = document.querySelector(id);
      element.classList.remove('hidden');
      chart.remove();
    } else {
      const element = document.querySelector(id);
      element.classList.remove('hidden');
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

  document.querySelectorAll('[telemetry-component="Form"]').forEach((form) => {
    form.querySelectorAll('input, select').forEach((input) => {
      input.addEventListener('change', () => form.submit());
    });
  });
});
