# Sharing static metrics pages

You can use the `TelemetryUI.Web.Share` controller to expose metrics rendering publicly on your application.

First you need to configure your theme with a secret share key

```elixir
[
  metrics: [
    {"Users", [count_over_time("myapp.users.created")]}
  ],
  backend: backend(),
  theme: %{
    share_key: "012345678912345",
    share_path: "/metrics/public"
    title: "User dashboard metrics"
  }
]
```

Add the controller to your `router.ex` without any scopes or pipelines.

```elixir
get("/metrics/public", TelemetryUI.Web.Share, [])
```

You should be able to see the "link" icon in your authenticated metrics page.

When clicking the "link" icon, you will be redirected to the `TelemetryUI.Web.Share` controller to render the metrics.
Data is embedded in the page so no authenticated requests are made for the public page (`metrics/public`) .

You can even render images of the VegaLite component by using the `id` attribute in the HTML in the URL params:

```
/metrics/public?id=MYID.png&share=b92feb0qfbnason
```
