# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Hamsat (hams.at) — a Phoenix/LiveView app for amateur radio satellite pass prediction and activation alerts. Orbital math (SGP4 pass/position calculation) comes from a forked `satellite_ex` dependency (git dep, `hamsat` branch). Set `LOCAL_DEPS_PATH` to use a local checkout of `satelliteEx` instead (see `mix.exs`).

## Commands

- `mix setup` — fetch deps, create/migrate DB, run seeds
- `bin/dev` — dev server (`iex -S mix phx.server`) at localhost:4000
- `mix test` — runs migrations automatically first
- `mix test test/hamsat/alerts_test.exs:42` — single test at a line
- `mix format`
- `bin/deploy` — Kamal deploy (sources `.envrc.prod`; config in `config/deploy.yml`)

The database is SQLite (`ecto_sqlite3`): `priv/repo/hamsat_dev.db` in dev, `hamsat_test.db` in test, `DATABASE_PATH` in prod. Secrets live age-encrypted in `env.toml` (decrypted via the master key / `SSE_MASTER_KEY`) — do not edit or decrypt it.

## Versions to be aware of

This app predates current Phoenix conventions — match the existing style, don't modernize:

- **LiveView 0.18** (not 1.0) — no `~p` in some older code paths, `phx-` API of that era, layouts via `Phoenix.View`
- **Phoenix.View** (`phoenix_view` package) with `lib/hamsat_web/views/` + `lib/hamsat_web/templates/` for non-LiveView pages; `phoenix_html` 3.x
- LiveViews use the `LiveEvent` library (`use LiveEvent.LiveView`, `emit/3`) for component→parent events

## Architecture

**`Hamsat.Context` is threaded everywhere.** A struct of `%{user, location, timezone, time_format}` (user may be `:guest`) built from the session by `HamsatWeb.ContextPlug` (controllers) and `HamsatWeb.ContextHook` (LiveViews, via `on_mount` in `HamsatWeb.live_view/0`). Context functions take it as their first argument. When no location is set, `Context.effective_location/1` falls back to grid FN31.

**Contexts** (`lib/hamsat/`): `Alerts` (activation alerts, saved alerts, pass matching), `Passes` (pass listing/lookup, backed by the ETS cache), `Satellites` (satellite/TLE data), `Accounts` (phx.gen.auth-style users). Contexts `use Hamsat, :repo` (imports Ecto.Query/Changeset, aliases Repo). Schemas live in `lib/hamsat/schemas/` and `use Hamsat, :schema` — binary UUID primary keys, `:utc_datetime` timestamps.

**OTP processes** (see `Hamsat.Application`):
- `Hamsat.Alerts.PassCache` — public ETS table caching computed passes in 6-hour buckets; pass computation is expensive, so go through the cache
- `Hamsat.Scheduler` — purges the pass cache daily
- `Hamsat.Satellites.PositionServer` — recomputes all satellite positions every second and serves them via `get_sat_positions/0`
- `Hamsat.Satellites.PeriodicSync` — keeps satellite/TLE data fresh

**Web layer** (`lib/hamsat_web/`): LiveViews in `live/<name>_live/` with colocated `.heex` templates and per-page `components/` subdirs; shared stateless function components in `components/`; stateful LiveComponents in `live_components/` (location picker, pass/sat trackers). Every LiveView gets `ContextHook`, `NavHook`, and `LocationModalHook` mounted automatically. There's a small JSON API (`/api/alerts/upcoming`, gated by `APIPlug` + API keys), Atom feeds under `/feeds`, and a `/up` health check.

**Tests** use a factory (`test/support/factory.ex`) plus fixtures in `test/support/fixtures/`.
