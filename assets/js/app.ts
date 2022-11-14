import vegaEmbed from 'vega-embed';

declare global {
  var drawChart: (id: string, spec: string) => void;
  var vegaComponentsLoaded: number;
}

const viewsById = {};
const heightsById = {};

const putLegendSelect = (view, value, legendItems) => {
  legendItems.forEach((item) => item.classList.add('opacity-50'));
  view.signal('tags_tags_legend', value).run();
};

const resetLegendSelect = (view, legendItems) => {
  legendItems.forEach((item) => item.classList.remove('opacity-50'));
  view.signal('tags_tags_legend', null).run();
};

const bindLegend = (id, view) => {
  const container = document.querySelector(id);
  const legend = document.querySelector(id + '-legend');
  if (!legend || !view._runtime.scales.color || !view._signals.tags_tags_legend)
    return;

  const legendItems = Array.from(
    legend.querySelectorAll('[telemetry-component="LegendItem"]')
  ) as HTMLElement[];

  container.addEventListener('click', () =>
    resetLegendSelect(view, legendItems)
  );
  legend.addEventListener('click', () => resetLegendSelect(view, legendItems));

  legendItems.forEach((item) => {
    item.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      putLegendSelect(view, item.dataset.value, legendItems);
      item.classList.remove('opacity-50');
    });
  });
};

const renderLegend = (id, view) => {
  const legend = document.querySelector(id + '-legend');
  if (!legend || !view._runtime.scales.color) return;

  legend.classList.remove('hidden');
  const colors = view.scale('color').range();
  const categories = view.scale('color').domain();

  const content = categories
    .sort((a, b) => (parseInt(a) || a) - (parseInt(b) || b))
    .map((category, i) => {
      const colorIndex = i - colors.length * Math.floor(i / colors.length);
      const color = colors[colorIndex];

      if (!category) return;

      return `<span
            telemetry-component="LegendItem"
            data-value="${category}"
            class="cursor-pointer hover:bg-neutral-50 hover:dark:bg-neutral-800 shrink-0 px-2 py-1 inline-block rounded-sm border-[1px] border-neutral-200 dark:border-neutral-800"
          >
            <span class="inline-block rounded-full h-[10px] w-[10px]" style="background: ${color};"></span>
            ${category}
          </span>`;
    })
    .filter(Boolean)
    .join('\n');

  legend.innerHTML = content;
};

const emptySource = (source) => {
  if (source.length === 0) return true;
  if (
    Array.from(source).every((data) => {
      const dataObject = data as {count: number};
      dataObject.count === 0;
    })
  )
    return true;

  return false;
};

const toggleFullscreen = (parentElement, id) => {
  const fixedStyle = [
    'fixed',
    'top-0',
    'left-0',
    'bottom-0',
    'right-0',
    'overflow-y-auto',
    'overflow-x-hidden',
    'z-10',
    'overscroll-contain',
    'dark:bg-neutral-900'
  ];

  if (parentElement.classList.contains('fixed')) {
    parentElement.classList.remove(...fixedStyle);
    parentElement.classList.add('relative');
    parentElement.classList.add('dark:bg-black/40');

    viewsById[id].signal('height', heightsById[id]);
  } else {
    parentElement.classList.add(...fixedStyle);
    parentElement.classList.remove('relative');
    parentElement.classList.remove('dark:bg-black/40');
    viewsById[id].signal('height', window.innerHeight - 130);
  }

  window.dispatchEvent(new Event('resize'));
};

window.drawChart = (id, spec) =>
  vegaEmbed(id, spec, {renderer: 'svg', actions: false}).then((result) => {
    const view = result.view;
    viewsById[id] = view;
    const source = view.data('source');
    vegaComponentsLoaded--;

    if (vegaComponentsLoaded <= 0) {
      for (const viewId in viewsById) {
        const element = document.querySelector(viewId) as HTMLElement;
        heightsById[viewId] = element.clientHeight;
        viewsById[viewId].signal('height', element.clientHeight);
      }
      window.dispatchEvent(new Event('resize'));
    }

    const loading = document.querySelector(id + '-loading') as HTMLElement;
    loading.classList.add('hidden');

    if (emptySource(source)) {
      const element = document.querySelector(id) as HTMLElement;
      const empty = document.querySelector(id + '-empty') as HTMLElement;
      empty.classList.remove('hidden');
      element.classList.add('hidden');
      element.classList.remove('vega-embed');
    } else {
      renderLegend(id, view);
      bindLegend(id, view);
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
      const OPTIONS = {dateStyle: 'long', timeStyle: 'short'} as const;

      const dateTimeFormat = new Intl.DateTimeFormat('en-US', OPTIONS);
      const title = time.getAttribute('title');
      if (!title) return;

      time.innerHTML = dateTimeFormat.format(new Date(title));
    });

  document
    .querySelectorAll('[telemetry-component="ToggleFullscreen"]')
    .forEach((button) => {
      const buttonElement = button as HTMLButtonElement;
      button.addEventListener('click', () => {
        toggleFullscreen(
          button.parentElement,
          '#' + buttonElement.dataset.viewId
        );
      });
    });

  document.querySelectorAll('[telemetry-component="Form"]').forEach((form) => {
    const formElement = form as HTMLFormElement;
    form.querySelectorAll('input, select').forEach((input) => {
      input.addEventListener('change', () => formElement.submit());
    });
  });
});
