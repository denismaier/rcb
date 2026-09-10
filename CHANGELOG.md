# Changelog

Notable changes to **RCB** (the `rcb-cascade` gem and the publishing
pipeline under `pub/`).

## 0.2.0 — 2026-09-10

Start resolution: rcb now relocates to the right build level before
doing anything.

- **Added:** `resolve_start` — a directory is *buildable* if it
  contains at least one per-level file (`rcb.rake`, `rcb.config.rb`,
  or `metadata.yaml`). Invoking rcb from a non-level directory (an
  article's `source/`, a grouping folder) now jumps to the nearest
  buildable ancestor, prints `→ running in <dir>`, and runs there.
  Invocations from a proper level are unchanged (no output, no
  relocation).
- **Fixed:** calling rcb from a non-level directory previously
  produced a plausible task list (exit 0) and wrote `.build/` with
  its manifest into the wrong directory — a real build would have
  resolved every relative task path against the wrong cwd.
- **Breaking (gem API):** `find_cascade(start_dir, root)` takes the
  pre-resolved root as a second argument and returns
  `[rakefiles, cascade_dirs]` instead of
  `[root, rakefiles, cascade_dirs]`. The `.rcbroot` and
  no-buildable guards moved to `resolve_start`. Affects only code
  that calls the gem directly; pipelines and rakefiles are
  unaffected. New guard: if nothing between the cwd and the project
  root is buildable, rcb refuses to run.

## 0.1.0 — 2026-08-28

Initial public release.

- **The gem** (`rcb/`): a lightweight cascading build system on Rake —
  walker from the working directory up to `.rcbroot`, two-phase loading
  (config → manifest → rakefiles), the shared `CFG` hash, file-task
  helpers, a warnings framework, and the CLI. ~230 lines; no
  pipeline knowledge.
- **The pipeline** (`pub/`): an academic publishing pipeline (DOCX →
  JATS XML → HTML/PDF) built on the gem — XProc cleanup steps, XSLT
  rendering, ConTeXt PDF, Lua filter chain, RNG + Schematron
  validation. Doubles as the runnable demo.

Design decisions and build history live in
[`docs/history.md`](docs/history.md); the forward-only roadmap in
[`docs/plans/roadmap.md`](docs/plans/roadmap.md).

Licensed under CC0-1.0 — see [LICENSE](LICENSE).