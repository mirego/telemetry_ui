import * as vega from 'vega';
import vegaEmbed from 'vega-embed';

declare global {
  var drawChart: (id: string, spec: string) => void;
}

interface ViewInternal {
  _runtime: any;
  _signals: any;
}

interface SelectOptions {
  multi: boolean;
}

const viewsById = {};
const heightsById = {};
const chartRefreshRate = 5000; // milliseconds
const chartDomainBuffer = 60000; // milliseconds

const onSelectTag = (
  view: vega.View,
  selectedItem: HTMLElement,
  legendItems: HTMLElement[],
  options: SelectOptions
) => {
  if (options.multi) {
    legendItems.forEach((item) => {
      item.classList.add('opacity-50');
      item.classList.add('truncate');
    });

    let items = legendItems.filter((item) => item.dataset.selected);
    if (selectedItem.dataset.selected) {
      selectedItem.removeAttribute('data-selected');
      items = items.filter(
        (item) => item.dataset.value !== selectedItem.dataset.value
      );
    } else {
      items = items.concat([selectedItem]);
    }

    const values = items.map((item) => atob(item.dataset.value as string));
    view.signal('tags_tags_legend', values).run();

    items.forEach((item) => {
      item.dataset.selected = 'true';
      item.classList.remove('opacity-50');
      item.classList.remove('truncate');
    });
  } else {
    if (selectedItem.dataset.selected) {
      resetLegendSelect(view, legendItems);
    } else {
      legendItems.forEach((item) => {
        item.removeAttribute('data-selected');
        item.classList.add('opacity-50');
        item.classList.add('truncate');
      });
      view
        .signal('tags_tags_legend', atob(selectedItem.dataset.value as string))
        .run();

      selectedItem.dataset.selected = 'true';
      selectedItem.classList.remove('opacity-50');
      selectedItem.classList.remove('truncate');
    }
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
      const mouseEvent = event as MouseEvent;
      mouseEvent.preventDefault();
      mouseEvent.stopPropagation();
      onSelectTag(view, item, legendItems, {multi: mouseEvent.shiftKey});
    });
  });

  view.addEventListener(
    'click',
    (event: Event, selectedItem: Item<any> | null | undefined) => {
      if (!selectedItem || !selectedItem.datum || !selectedItem.datum['tags'])
        return;

      const mouseEvent = event as MouseEvent;
      mouseEvent.preventDefault();
      mouseEvent.stopPropagation();

      const item = legendItems.find(
        (item) => item.dataset.value === btoa(selectedItem.datum['tags'])
      );
      if (!item) return;
      onSelectTag(view, item, legendItems, {multi: mouseEvent.shiftKey});
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
  const itemsCount = Array.from(
    legend.querySelectorAll('[telemetry-component="LegendItem"]')
  ).length;

  const colors = view.scale('color').range();
  const categories = view.scale('color').domain();

  if (itemsCount !== 0 && itemsCount === categories.length) return false;

  const selectedValues = Array.from(
    legend.querySelectorAll('[data-selected="true"]')
  ).map((item) => item.dataset.value);

  const content = categories
    .sort((a, b) => (parseInt(a) || a) - (parseInt(b) || b))
    .map((category: string, index: number) => {
      const colorIndex =
        index - colors.length * Math.floor(index / colors.length);
      const color = colors[colorIndex];

      if (!category) return;

      const categoryValue = btoa(category);

      return `<span
            telemetry-component="LegendItem"
            data-value="${categoryValue}"
            class="truncate max-w-full cursor-pointer hover:bg-neutral-50 hover:dark:bg-neutral-800 shrink-0 px-2 py-1 inline-block rounded-sm border-[1px] border-neutral-200 dark:border-neutral-800"
          >
            <span class="inline-block rounded-full h-[10px] w-[10px]" style="background: ${color};"></span>
            ${category}
          </span>`;
    })
    .filter(Boolean)
    .join('\n');

  legend.innerHTML = content;

  const legendItems = Array.from(
    legend.querySelectorAll('[telemetry-component="LegendItem"]')
  ) as HTMLElement[];

  legendItems.forEach((item) => {
    if (selectedValues.includes(item.dataset.value)) {
      onSelectTag(view, item, legendItems, {multi: true});
    }
  });

  return true;
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

const toggleFullscreen = (parentElement: HTMLElement, id: string) => {
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
  const closeButton = parentElement.querySelector('.close-fullscreen-button');

  if (parentElement.classList.contains('fixed')) {
    parentElement.classList.remove(...fixedStyle);
    parentElement.classList.add('relative');
    parentElement.classList.add('dark:bg-black/40');
    closeButton.classList.add('hidden');

    viewsById[id].signal('height', heightsById[id]);
  } else {
    parentElement.classList.add(...fixedStyle);
    parentElement.classList.remove('relative');
    parentElement.classList.remove('dark:bg-black/40');
    closeButton.classList.remove('hidden');

    heightsById[id] = viewsById[id].signal('height');
    viewsById[id].signal('height', window.innerHeight - 130);
  }

  window.dispatchEvent(new Event('resize'));
};

window.drawChart = async (id, spec) => {
  const {view} = await vegaEmbed(id, spec, {
    renderer: 'svg',
    actions: {
      export: {svg: false},
      source: true,
      compiled: false,
      editor: false
    }
  });

  if (spec.data.url) {
    setInterval(async () => {
      const response = await fetch(spec.data.url);
      const data = await response.json();

      const now = Number(new Date());
      const [currentDomainFrom, currentDomainTo] = view.signal('date_domain');
      let changeset = vega
        .changeset()
        .remove(() => true)
        .insert(data);
      view.change('source', changeset);
      view.signal('date_domain', [
        now - (currentDomainTo - currentDomainFrom - chartDomainBuffer),
        now + chartDomainBuffer
      ]);

      view.run();
      window.dispatchEvent(new Event('resize'));

      setSideElements(view, id);
    }, chartRefreshRate);
  }

  setSideElements(view, id);

  const loading = document.querySelector(id + '-loading') as HTMLElement;
  loading.classList.add('hidden');

  viewsById[id] = view;
};

const setSideElements = (view, id) => {
  const title = document.querySelector(id + '-title') as HTMLElement;
  const element = document.querySelector(id) as HTMLElement;
  const legend = document.querySelector(id + '-legend') as HTMLElement;
  const empty = document.querySelector(id + '-empty') as HTMLElement;

  if (emptySource(view.data('source'))) {
    title.classList.remove('hidden');
    empty.classList.remove('hidden');
    element.classList.add('hidden');
    element.classList.remove('vega-embed');
    legend.classList.add('hidden');
  } else {
    title.classList.add('hidden');
    empty.classList.add('hidden');
    element.classList.remove('hidden');
    element.classList.add('vega-embed');

    const renderedLegend = renderLegend(id, view);
    if (renderedLegend) bindLegend(element, id, view);
  }
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
        if (!button.parentElement) return;

        toggleFullscreen(
          button.parentElement,
          '#' + buttonElement.dataset.viewId
        );
      });
    });

  document.querySelectorAll('[telemetry-component="Form"]').forEach((form) => {
    const formElement = form.querySelector('form') as HTMLFormElement;
    form.querySelectorAll('input, select').forEach((input) => {
      input.addEventListener('change', () => formElement.submit());
    });
  });
});
