defmodule Mailbag.Mixfile do
  use Mix.Project

  def project do
    [app: :mailbag,
     version: "0.0.1",
     elixir: "~> 1.1",
     source_url: "https://github.com/migadu/mailbag",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :tzdata]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:timex, "~> 0.19.5"},
      {:ex_doc, "~> 0.10", only: :dev},
      {:benchfella, "~> 0.2", only: :dev},
      {:dialyze, "~> 0.2", only: :dev},
      {:inch_ex, "== 0.3.3", only: :docs}
    ]
  end
end
