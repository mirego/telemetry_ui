document
  .querySelectorAll('[telemetry-component="Chart"]')
  .forEach((element) => {
    const font = {
      family:
        'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"',
      size: 13,
    };
    let xaxisType = "-";

    const data = JSON.parse(element.dataset.payload).map(function (data) {
      return Object.assign(data, {
        x: data.x.map(function (value) {
          if (/\d\d\d\d-\d\d-\d\d/.test(value)) {
            return new Date(value);
          } else {
            xaxisType = "category";
            return value;
          }
        }),
      });
    });

    const layout = {
      font,
      showlegend: data.length > 1,
      showTips: false,
      hovermode: "x",
      hoverdistance: 50,
      margin: { t: 20, l: 40, b: 40, r: 20, pad: 5 },
      responsive: true,
      xaxis: { type: xaxisType },
      height: 200,
      paper_bgcolor: 'transparent',
      plot_bgcolor: 'transparent',
      ...JSON.parse(element.dataset.layout),
    };

    window.loadScript(
      "https://cdn.plot.ly/plotly-2.13.3.min.js",
      () => !!window.Plotly,
      () => Plotly.newPlot(element, data, layout, { displayModeBar: false })
    );
  });
