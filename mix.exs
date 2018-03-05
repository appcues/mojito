defmodule X1Client.MixProject do
  use Mix.Project

  def project do
    [
      app: :x1client,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:fuzzyurl, "~> 0.9 or ~> 1.0"},
      {:poolboy, "~> 1.5"},
      {:ex_spec, "~> 2.0", only: :test},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false}
    ]
  end
end
