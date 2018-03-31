defmodule XClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :xclient,
      description: "XClient is an HTTP client based on XHTTP.",
      version: "0.7.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      dialyzer: [
        plt_add_apps: [:mix]
      ],
      aliases: [
        docs: "docs --source-url https://github.com/appcues/xclient"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["pete gamache <pete@appcues.com>"],
      links: %{github: "https://github.com/appcues/xclient"}
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {XClient.Application, []}
    ]
  end

  defp deps do
    [
      {:xhttp, github: "ericmj/xhttp"},
      {:fuzzyurl, "~> 1.0"},
      {:poolboy, "~> 1.5"},
      {:ex_spec, "~> 2.0", only: :test},
      {:jason, "~> 1.0", only: :test},
      {:cowboy, "~> 1.1", only: :test},
      {:plug, "~> 1.3", only: :test},
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false}
    ]
  end
end
