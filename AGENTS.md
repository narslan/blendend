# Repository Guidelines

## Project Structure & Module Organization
- Elixir source in `lib/` (canvas, path, text, style modules); tests in `test/` with helpers in `test/support/`.
- Native NIF C++17 code lives in `c_src/`; builds to `priv/blendend.so`.
- Assets/fonts in `priv/`; `_build/` and `deps/` are generated; `Makefile` drives the native build via `elixir_make`.

## Build, Test, and Development Commands
- `mix deps.get` — install Elixir deps.
- `mix compile` — build Elixir + NIF (needs Blend2D and a C++ toolchain).
- `make` (optional) — manual native build; add `DEBUG=1` for symbols.
- `mix test` or `MIX_ENV=test mix test --trace` — run ExUnit.
- `mix format` / `mix format --check-formatted` — apply or verify formatting.

## Coding Style & Naming Conventions
- Use the default formatter; 2-space indent and pipeline-friendly layout.
- Modules are CamelCase; functions/vars snake_case; tests named `*_test.exs`.
- Keep NIF wrappers thin and return updated structs for piping.
- C++ builds with `-std=c++17 -Wall -Wextra -fPIC`; keep files scoped to a domain.
- Use the snak_case convention of latest `blend2d`
## Testing Guidelines
- ExUnit only; `test/support/` is already on the test path.
- Use descriptive strings in `describe` blocks; add regressions for NIF safety (see `test/nif_*_test.exs`).
- Write any rendered outputs to `test/tmp/` and avoid committing artifacts.

## Playground (blendend_playground)
- Lives at `../blendend_playground` with `{:blendend, path: "../blendend"}`; it runs against your local checkout.
- From that directory: `mix deps.get` then `mix run --no-halt`; open `http://localhost:4000`.
- Restart after NIF/C++ changes; if stale, run `mix deps.clean blendend && mix deps.get` in the playground to rebuild.
- Backend executes submitted code—use only on trusted machines.
- Masks: load via `Image.from_file_a8!/2` (choose channel like `:red` or `:luma`) before `Canvas.Mask.fill!/5`; pass `fill:` + `alpha:` per draw.

## Commit & Pull Request Guidelines
- Commit subjects: short, imperative (e.g., `add canvas clipping check`); one logical change per commit.
- PRs should state intent, native/build impacts (Blend2D, toolchain), and command output (`mix test`, `mix format --check-formatted`); include renders only when they clarify a visual change.

## Native Dependencies & Environment
- Blend2D must be installed and linkable (`-lblend2d`); headers available to `g++`.
- Keep flags/paths in `Makefile` so `elixir_make` stays reproducible.
- If `blendend.so` fails to load, ensure `priv/` has a fresh build and your system can locate Blend2D libs.
