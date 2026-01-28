defmodule Klime.MixProject do
  use Mix.Project

  @version "1.0.1"
  @source_url "https://github.com/klimeapp/klime-elixir"

  def project do
    [
      app: :klime,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Klime",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      # Optional - for Plug middleware
      {:plug, "~> 1.14", optional: true},
      # Dev/test only
      {:bypass, "~> 2.1", only: :test},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Klime SDK for Elixir - Track events, identify users, and group them with organizations."
  end

  defp package do
    [
      name: "klime",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      maintainers: ["Klime"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE.md CONTRIBUTING.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CONTRIBUTING.md", "LICENSE.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
