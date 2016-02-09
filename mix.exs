defmodule EvercamMedia.Mixfile do
  use Mix.Project

  def project do
    [app: :evercam_media,
     version: "1.0.1",
     elixir: "> 1.0.0",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     compilers: [:make, :phoenix] ++ Mix.compilers,
     aliases: aliases,
     deps: deps]
  end

  defp aliases do
    [clean: ["clean", "clean.make"]]
  end

  def application do
    [mod: {EvercamMedia, []},
     applications: app_list(Mix.env)]
  end

  defp app_list(:dev), do: [:dotenv, :credo | app_list]
  defp app_list(_), do: app_list
  defp app_list, do: [
    :calecto,
    :con_cache,
    :connection,
    :cowboy,
    :ecto,
    :erlcloud,
    :ex_aws,
    :exq,
    :httpotion,
    :runtime_tools,
    :tzdata,
    :httpoison,
    :inets,
    :mailgun,
    :phoenix,
    :phoenix_ecto,
    :phoenix_html,
    :porcelain,
    :postgrex,
    :calendar,
    :timex,
    :quantum,
    :uuid,
    :xmerl
  ]

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  defp deps do
    [{:phoenix, "~> 1.1"},
     {:phoenix_html, "~> 2.5"},
     {:phoenix_ecto, "~> 2.0"},
     {:postgrex, ">= 0.11.0"},
     {:cowboy, "~> 1.0"},
     {:ex_aws, github: "CargoSense/ex_aws"},
     {:quantum, github: "c-rack/quantum-elixir"},
     {:con_cache, "~> 0.10.0"},
     {:httpotion, "~> 2.0"},
     {:ibrowse, "~> 4.2", override: true},
     {:httpoison, "~> 0.8.1"},
     {:calendar, "~> 0.12.3"},
     {:calecto, "~> 0.5.0"},
     {:dotenv, "~> 2.0.0", only: :dev},
     {:poison, "~> 1.5"},
     {:porcelain, "~> 2.0.1"},
     {:erlcloud, github: "gleber/erlcloud"},
     {:exq, "~> 0.6.2"},
     {:uuid, "~> 1.1"},
     {:exrm, github: "bitwalker/exrm"},
     {:credo, github: "rrrene/credo", only: :dev},
     {:mailgun, github: "chrismccord/mailgun"}]
  end
end

defmodule Mix.Tasks.Compile.Make do
  @shortdoc "Compiles helper in src/"

  def run(_) do
    {result, _error_code} = System.cmd("make", [], stderr_to_stdout: true)
    Mix.shell.info result

    :ok
  end
end

defmodule Mix.Tasks.Clean.Make do
  @shortdoc "Cleans helper in src/"

  def run(_) do
    {result, _error_code} = System.cmd("make", ['clean'], stderr_to_stdout: true)
    Mix.shell.info result

    :ok
  end
end
