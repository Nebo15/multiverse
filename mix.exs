defmodule Multiverse.Mixfile do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :multiverse,
      description: "Plug that allows to add version compatibility layers via API request/response gateways.",
      package: package(),
      version: @version,
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      docs: [source_ref: "v#{@version}", main: "readme", extras: ["README.md"]],
      dialyzer: [ignore_warnings: "dialyzer.ignore-warnings"]
    ]
  end

  defp elixirc_paths(:test), do: elixirc_paths(:dev) ++ ["test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [extra_applications: [:plug]]
  end

  defp deps do
    [
      {:plug, "~> 1.4"},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test]},
      {:excoveralls, ">= 0.5.0", only: [:dev, :test]},
      {:dogma, ">= 0.1.0", only: [:dev, :test]},
      {:credo, ">= 0.4.0", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      contributors: ["Andrew Dryga"],
      maintainers: ["Andrew Dryga"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/Nebo15/multiverse"},
      files: ~w(lib LICENSE.md mix.exs README.md)
    ]
  end
end
