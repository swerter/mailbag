defmodule Mix.Tasks.Compile.Iconv do
  @shortdoc "Compiles Iconv"
  def run(_) do
    if not File.exists?("priv/Elixir.Iconv_nif.so") do
      [i_erts]=Path.wildcard("#{:code.root_dir}/erts*/include")
      i_ei=:code.lib_dir(:erl_interface,:include)
      l_ei=:code.lib_dir(:erl_interface,:lib)
      args = " -L#{l_ei} -lerl_interface -lei -I#{i_ei} -I#{i_erts} -Wall -shared -fPIC "
      args = args <> if {:unix,:darwin}==:os.type, do: "-undefined dynamic_lookup -dynamiclib", else: ""
      Mix.shell.info to_string :os.cmd('gcc #{args} -v -o priv/Elixir.Iconv_nif.so c_src/iconv_nif.c')
    end
  end
end

defmodule Mailbag.Mixfile do
  use Mix.Project

  def project do
    [app: :mailbag,
     version: "0.0.1",
     elixir: "~> 1.1",
     description: "A library for reading emails stored in the maildir format",
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     compilers: [:iconv, :elixir, :app],
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :tzdata]]
  end

  defp package do
    [ files: ["lib", "priv", "mix.exs", "README.md", "LICENSE.md"],
      contributors: ["Michael Bruderer", "Dejan Strbac"],
      licenses: ["MIT"],
      links: %{ "GitHub": "https://github.com/migadu/mailbag" } ]
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
