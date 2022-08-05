document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('[telemetry-component="Form"]').forEach((form) => {
    form.querySelectorAll('input, select').forEach((input) => {
      input.addEventListener('change', () => form.submit());
    });
  });
});

window.loadScript = (url, predicate, callback) => {
  if (predicate()) return callback();
  const script = document.createElement('script');

  script.async = true;
  script.src = url;
  script.onload = callback;

  (
    document.getElementsByTagName('head')[0] ||
    document.getElementsByTagName('body')[0]
  ).appendChild(script);
};
