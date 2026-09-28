# Changelog

Notable changes to **RCB** (the `rcb-cascade` gem and the publishing
pipeline under `pub/`).

## Unreleased

Pipeline fixes and metadata cleanup (no gem code changes; the gem
stays at 0.2.0).

- **Fixed (pipeline):** `init_article` now derives the suggested article
  number from the highest existing article directory in the volume
  (parsed from the `<abbrev>-<year>-<num>-<slug>` pattern) instead of
  counting directories — starting mid-volume no longer suggests
  numbers that collide with earlier articles.
- **Fixed (pipeline):** Ctrl+C during the `init_article` prompts now
  aborts cleanly with an "Aborted." message instead of an unhandled
  `Interrupt` backtrace.
- **Changed (gem metadata):** gem description and README no longer
  reference doit-cascade; they describe the cascade mechanism itself.
- **Fixed (pipeline):** ConTeXt templates no longer hardcode the
  journal name ("Judaica: Neue digitale Folge"): `jats.tex` now
  registers `<journal-meta>` and fills the document variables
  `journal-title` (from `<journal-title>`) and `journal-abbrev`
  (from `<abbrev-journal-title>`). The title block shows the full
  journal name, the footer variant the abbreviation — building
  another journal labels its PDF correctly, like HTML already did.
- **Changed (pipeline/demo):** The demo publisher now carries its own
  font level using only ConTeXt-bundled fonts: `demoverlag/_assets/
  context/_layout_doc_fonts.tex` (TeX Gyre Pagella as the default
  body, Heros as sans). dhr shadows it with a copy that switches the
  body to sans (`\setupbodyfont[mainface,ss,11pt]`) plus a paragraph
  override (space between paragraphs instead of first-line indent),
  so the two demo journals contrast serif+indent against
  grotesk+block paragraphs. jds therefore moves from Cardo to
  Pagella; the production baseline (Cardo/Myriad + script fallbacks)
  stays with JNDF.

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