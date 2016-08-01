defmodule Multiverse.Mixfile do
  use Mix.Project

  def project do
    [app: :multiverse,
     description: "Manage version of your API via request and response gateways.",
     package: package,
     version: "0.2.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: [coveralls: :test]]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [{:timex, "~> 3.0"},
     {:cowboy, "~> 1.0"},
     {:plug, "~> 1.0"},
     {:ex_doc, ">= 0.0.0", only: [:dev, :test]},
     {:excoveralls, "~> 0.5", only: [:dev, :test]},
     {:dogma, "~> 0.1", only: [:dev, :test]},
     {:credo, "~> 0.4", only: [:dev, :test]}]
  end

  defp package do
    [contributors: ["Andrew Dryga"],
     maintainers: ["Andrew Dryga"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/Nebo15/multiverse"},
     files: ~w(lib LICENSE.md mix.exs README.md)]
  end
end
