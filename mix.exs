defmodule Ersatz.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :ersatz,
      version: @version,
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      name: "Ersatz",
      description: "Mocks defined from behaviours for Elixir",
      source_url: "https://github.com/apemb/ersatz",
      docs: [
        main: "Ersatz",
        source_ref: "v_#{@version}"
      ],
      deps: deps(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Ersatz.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:espec, "~> 1.7.0"}
    ]
  end

  defp package do
    %{
      licenses: ["Apache 2"],
      maintainers: ["Antoine Boileau"],
      links: %{
        "GitHub" => "https://github.com/apemb/ersatz"
      }
    }
  end
end
