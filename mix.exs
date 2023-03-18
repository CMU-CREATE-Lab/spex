defmodule Spex.MixProject do
  use Mix.Project

  def project do
    [
      app: :spex,
      version: "0.1.0-dev",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # docs
      name: "Spex",
      source_url: "https://github.com/CMU-CREATE-Lab/spex",
      docs: [
        main: "Spex",
        extras: ["README.md"],
        ],
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # numerical compute
      # {:nx, "~> 0.1"},
      # {:exla, "~> 0.1"},
      # {:torchx, "~> 0.1"},
      {:exla, "~> 0.1", github: "elixir-nx/nx", sparse: "exla"},
      {:torchx, "~> 0.1", github: "elixir-nx/nx", sparse: "torchx"},
      {:nx, "~> 0.1", github: "elixir-nx/nx", sparse: "nx", override: true},
      # html/json/excel parsing
      {:floki, "~> 0.34"},
      {:jason, "~> 1.2"},
      {:xlsxir, "~> 1.6"},
      # time zones
      {:tzdata, "~> 1.1"},

      # generate documentation
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},


      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
