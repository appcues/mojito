defmodule Mojito.MixProject do
  use Mix.Project

  @version "0.7.8"
  @repo_url "https://github.com/appcues/mojito"

  def project do
    [
      app: :mojito,
      description: "Fast, easy to use HTTP client based on Mint",
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      dialyzer: [
        plt_add_apps: [:mix]
      ],
      docs: [
        logo: "assets/mojito.png",
        main: "Mojito",
        source_ref: @version,
        source_url: @repo_url
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      maintainers: [
        "pete gamache <pete@appcues.com>",
        "andy leclair <andy@appcues.com>"
      ],
      links: %{github: @repo_url}
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Mojito.Application, []}
    ]
  end

  defp deps do
    [
      {:mint, "~> 1.1"},
      {:castore, "~> 0.1"},
      {:poolboy, "~> 1.5"},
      {:telemetry, "~> 0.4"},
      {:ex_spec, "~> 2.0", only: :test},
      {:jason, "~> 1.0", only: :test},
      {:cowboy, "~> 2.0", only: :test},
      {:plug, "~> 1.3", only: :test},
      {:plug_cowboy, "~> 2.0", only: :test},
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
