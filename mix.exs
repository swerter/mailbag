defmodule Mix.Tasks.Compile.CLibs do
  @shortdoc "Compiles C libraries"
  def run(_) do
    # if not File.exists?("priv/Elixir.Iconv_nif.so") do
    #   [i_erts]=Path.wildcard("#{:code.root_dir}/erts*/include")
    #   i_ei=:code.lib_dir(:erl_interface,:include)
    #   l_ei=:code.lib_dir(:erl_interface,:lib)
    #   args = " -L#{l_ei} -lerl_interface -lei -I#{i_ei} -I#{i_erts} -Wall -shared -fPIC "
    #   args = args <> if {:unix,:darwin}==:os.type, do: "-undefined dynamic_lookup -dynamiclib", else: ""
    #   Mix.shell.info to_string :os.cmd('gcc #{args} -v -o priv/Elixir.Iconv_nif.so c_src/iconv_nif.c')
    # end
    File.mkdir_p "priv"
    if not File.exists?("priv/extract_text") do
      args = "-Wall -O0 -ggdb3 `pkg-config --cflags --libs gmime-2.6`"
      Mix.shell.info to_string :os.cmd('gcc #{args} -v -o priv/extract_text c_src/extract_text.c')
    end
    if not File.exists?("priv/extract_structure") do
      args = "-Wall -O0 -ggdb3 `pkg-config --cflags --libs gmime-2.6`"
      Mix.shell.info to_string :os.cmd('gcc #{args} -v -o priv/extract_structure c_src/extract_structure.c')
    end
    if not File.exists?("priv/extract_headers") do
      args = "-Wall -O0 -ggdb3 `pkg-config --cflags --libs gmime-2.6`"
      Mix.shell.info to_string :os.cmd('gcc #{args} -v -o priv/extract_headers c_src/extract_headers.c')
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
     compilers: [:c_libs, :elixir, :app],
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :tzdata]] #, :porcelain
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
      {:inch_ex, "== 0.3.3", only: :docs},
      # {:porcelain, "~> 2.0"}
    ]
  end
end
