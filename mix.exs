defmodule ExQuery.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exq,
      description: "Library for generating functions to match collection of maps",
      version: "0.0.1",
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      package: package
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    []
  end

  defp package do
    [
      licenses: "BSD",
      links: %{
        "GitHub" => "https://github.com/lafka/exq"
      },
      contributors: ["Olav Frengstad"]
    ]
  end
end
