[
  inputs: [
    "mix.exs",
    ".formatter.exs",
    ".credo.exs",
    "priv/my-app/*.{ex,exs}",
    "priv/my-app/{config,lib,priv}/**/*.{ex,exs,heex}",
    "priv/{static}/**/*.{ex,exs}",
    "{config,lib,test,rel}/**/*.{ex,exs}"
  ],
  subdirectories: ["priv/my-app"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  import_deps: [:ecto, :phoenix],
  line_length: 180
]
