defmodule X1Client.MixProject do
  use Mix.Project

  def project do
    [
      app: :x1client,
      version: "0.6.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      aliases: [
        docs: "docs --source-url https://github.com/appcues/x1client"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["pete gamache <pete@appcues.com>"],
      links: %{github: "https://github.com/appcues/x1client"}
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {X1Client.Application, []}
    ]
  end

  defp deps do
    [
      {:xhttp, github: "ericmj/xhttp"},
      {:poolboy, "~> 1.5"},
      {:ex_spec, "~> 2.0", only: :test},
      {:cowboy, "~> 1.1", only: :test},
      {:plug, "~> 1.3", only: :test},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false}
    ]
  end
end
