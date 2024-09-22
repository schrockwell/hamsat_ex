defmodule Hamsat.MixProject do
  use Mix.Project

  def project do
    [
      app: :hamsat,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Hamsat.Application, []},
      extra_applications: [:logger, :runtime_tools, :inets, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    local_deps() ++
      [
        {:bcrypt_elixir, "~> 2.0"},
        {:phoenix, "~> 1.7.7"},
        {:phoenix_ecto, "~> 4.4"},
        {:ecto_sql, "~> 3.11.1"},
        {:postgrex, ">= 0.0.0"},
        {:phoenix_html, "~> 3.0"},
        {:phoenix_live_reload, "~> 1.2", only: :dev},
        {:phoenix_view, "~> 2.0"},
        {:phoenix_live_view, "~> 0.18.18"},
        {:phoenix_live_dashboard, "~> 0.7.2"},
        {:floki, ">= 0.30.0", only: :test},
        {:esbuild, "~> 0.4", runtime: Mix.env() == :dev},
        {:swoosh, "~> 1.3"},
        {:telemetry_metrics, "~> 0.6"},
        {:telemetry_poller, "~> 1.0"},
        {:gettext, "~> 0.18"},
        {:jason, "~> 1.2"},
        {:plug_cowboy, "~> 2.5"},
        {:tailwind, "~> 0.2.3", runtime: Mix.env() == :dev},
        {:timex, "~> 3.7"},
        {:hackney, "~> 1.20.1"},
        {:ex_heroicons, "~> 2.0.0"},
        {:atomex, "~> 0.5.1"},
        {:httpoison, "~> 2.2.1"},
        {:live_inspect, "~> 0.2"},
        {:live_event, "0.3.0"}
      ]
  end

  defp local_deps do
    if path = System.get_env("LOCAL_DEPS_PATH") do
      [
        # {:live_inspect, path: Path.join(path, "live_inspect")},
        # {:live_event, path: Path.join(path, "live_event")},
        {:satellite_ex, path: Path.join(path, "satelliteEx")}
      ]
    else
      [
        # {:live_inspect, "~> 0.2"},
        # {:live_event, "0.3.0"},
        {:satellite_ex, git: "https://github.com/schrockwell/satelliteEx.git", branch: "hamsat"}
      ]
    end
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
