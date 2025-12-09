defmodule Blendend.MixProject do
  use Mix.Project

  def project do
    [
      app: :blendend,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:elixir_make] ++ Mix.compilers(),
      deps: deps(),
      docs: [
        main: "readme",
        logo: "docs/images/logo.png",
        assets: %{"docs/images" => "docs/images"},
        extras: [
          "README.md",
          "notebooks/blendend_intro.livemd"
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex_doc, "~> 0.39.2", only: :dev, runtime: false, warn_if_outdated: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:elixir_make, "~> 0.9.0"}
    ]
  end
end
