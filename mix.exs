defmodule Eddb.MixProject do
  use Mix.Project

  def project do
    [
      app: :eddb,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Eddb, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},
      {:poison, "~> 6.0"},
      {:cluster_bot, "~> 0.2.0"},
      {:yajwt, "~> 1.0"},
      {:joken, "~> 2.6"}
    ]
  end
end
