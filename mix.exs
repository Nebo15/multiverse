defmodule Multiverse.Mixfile do
  use Mix.Project

  def project do
    [app: :multiverse,
     description: "API Gateway versioning plug",
     package: package,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :cowboy, :plug]]
  end

  defp deps do
    [{:timex, "~> 3.0"},
     {:cowboy, "~> 1.0"},
     {:plug, "~> 1.0"}]
  end

  defp package do
    [contributors: ["Andrew Dryga"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/Nebo15/multiverse"},
     files: ~w(lib LICENSE.md mix.exs README.md)]
  end
end
