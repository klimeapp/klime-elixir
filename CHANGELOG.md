# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-01-28

- **BREAKING:** Simplified API to use application config instead of passing client reference to every function call
  - Configure once in `config/config.exs` with `config :klime, write_key: "..."`
  - Add `Klime.Client` directly to supervision tree (no options needed)
  - All functions now use module calls: `Klime.track("Event", %{}, user_id: "123")` instead of `Klime.track(client, "Event", %{}, user_id: "123")`
- Function arities reduced: `track/4` → `track/3`, `identify/3` → `identify/2`, `group/4` → `group/3`, `flush/1` → `flush/0`, `shutdown/1` → `shutdown/0`

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
