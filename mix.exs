defmodule Eddb.MixProject do
  use Mix.Project

  def project do
    [
      app: :eddb,
      version: "0.9.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),

      name: "Eddb",
      source_url: "https://github.com/micartey/elixir-distributed-database",
      docs: [
        main: "readme",
        source_ref: "master",
        extras: ["README.md", "LICENSE"]
      ]
    ]
  end

  defp description() do
    "Distirbuted database for unstructured data"
  end


  defp package() do
    [
      name: "eddb",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/micartey/elixir-distributed-database"}
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
      {:joken, "~> 2.6"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
    ]
  end
end
