# Changelog

Notable changes to **RCB** (the `rcb-cascade` gem and the publishing
pipeline under `pub/`).

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