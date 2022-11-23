import {Item, View} from 'vega';
import vegaEmbed from 'vega-embed';

declare global {
  var drawChart: (id: string, spec: string) => void;
}

interface ViewInternal {
  _runtime: any;
  _signals: any;
}

const viewsById = {};
const heightsById = {};

const putLegendSelect = (
  view: View,
  value: string,
  legendItems: HTMLElement[]
) => {
  legendItems.forEach((item) => {
    item.classList.add('opacity-50');
    item.classList.add('truncate');
  });
  view.signal('tags_tags_legend', atob(value)).run();
};

const onSelectTag = (
  view: View,
  item: HTMLElement,
  legendItems: HTMLElement[]
) => {
  if (item.dataset.selected) {
    resetLegendSelect(view, legendItems);
  } else {
    putLegendSelect(view, item.dataset.value as string, legendItems);
    item.dataset.selected = 'true';
    item.classList.remove('opacity-50');
    item.classList.remove('truncate');
  }
};

const resetLegendSelect = (view: View, legendItems: HTMLElement[]) => {
  legendItems.forEach((item) => {
    item.removeAttribute('data-selected');
    item.classList.remove('opacity-50');
    item.classList.add('truncate');
  });
  view.signal('tags_tags_legend', null).run();
};

const bindLegend = (element: HTMLElement, id: string, viewUnknown: unknown) => {
  const legend = document.querySelector(id + '-legend');
  const runtime = (viewUnknown as ViewInternal)._runtime;
  const signals = (viewUnknown as ViewInternal)._signals;
  const view = viewUnknown as View;

  if (!legend || !runtime.scales.color || !signals.tags_tags_legend) return;

  const legendItems = Array.from(
    legend.querySelectorAll('[telemetry-component="LegendItem"]')
  ) as HTMLElement[];

  legendItems.forEach((item) => {
    if (!item.dataset.value) return;

    item.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      onSelectTag(view, item, legendItems);
    });
  });

  view.addEventListener(
    'click',
    (event: Event, selectedItem: Item<any> | null | undefined) => {
      if (!selectedItem || !selectedItem.datum || !selectedItem.datum['tags'])
        return;

      event.preventDefault();
      event.stopPropagation();

      const item = legendItems.find(
        (item) => item.dataset.value === btoa(selectedItem.datum['tags'])
      );
      if (!item) return;
      onSelectTag(view, item, legendItems);
    }
  );

  element.addEventListener('click', () => resetLegendSelect(view, legendItems));
  legend.addEventListener('click', () => resetLegendSelect(view, legendItems));
};

const renderLegend = (id: string, viewUnknown: unknown) => {
  const runtime = (viewUnknown as ViewInternal)._runtime;
  const view = viewUnknown as View;

  const legend = document.querySelector(id + '-legend');
  if (!legend || !runtime.scales.color) return;

  legend.classList.remove('hidden');
  const colors = view.scale('color').range();
  const categories = view.scale('color').domain();

  const content = categories
    .sort((a, b) => (parseInt(a) || a) - (parseInt(b) || b))
    .map((category: string, index: number) => {
      const colorIndex =
        index - colors.length * Math.floor(index / colors.length);
      const color = colors[colorIndex];

      if (!category) return;

      return `<span
            telemetry-component="LegendItem"
            data-value="${btoa(category)}"
            class="truncate max-w-full cursor-pointer hover:bg-neutral-50 hover:dark:bg-neutral-800 shrink-0 px-2 py-1 inline-block rounded-sm border-[1px] border-neutral-200 dark:border-neutral-800"
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

    heightsById[id] = viewsById[id].signal('height');
    viewsById[id].signal('height', window.innerHeight - 130);
  }

  window.dispatchEvent(new Event('resize'));
};

window.drawChart = async (id, spec) => {
  const {view} = await vegaEmbed(id, spec, {renderer: 'svg', actions: false});
  const element = document.querySelector(id) as HTMLElement;

  if (emptySource(view.data('source'))) {
    const empty = document.querySelector(id + '-empty') as HTMLElement;
    empty.classList.remove('hidden');
    element.classList.add('hidden');
    element.classList.remove('vega-embed');
  } else {
    renderLegend(id, view);
    bindLegend(element, id, view);
  }

  const loading = document.querySelector(id + '-loading') as HTMLElement;
  loading.classList.add('hidden');

  viewsById[id] = view;
};

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
