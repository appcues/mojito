defmodule X1Client.MixProject do
  use Mix.Project

  def project do
    [
      app: :x1client,
      version: "0.1.0",
      elixir: "~> 1.6",
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
      {:fuzzyurl, "~> 0.9"},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false}
    ]
  end
end
