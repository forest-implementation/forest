defmodule Forest.MixProject do
  use Mix.Project

  def project do
    [
      app: :forest,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:hacko, github: "forest-implementation/hacko"},
      {:randixir, "~> 0.1.0"},
      {:nimble_csv, "~> 1.1", only: :example},
      {:statistex_robust, "~> 0.1.1", only: [:test, :example]}
    ]
  end
end
