# CLAUDE.md

Guidance for Claude Code working in this repository.

## Project

RCB (Ruby Cascade Build) — lightweight cascading Rake-based build
system. Demo project under `pub/` is an academic publishing
pipeline (DOCX → JATS XML → HTML/PDF).

## Commands

Use `rcb-dev` (the dev wrapper) — **not** `rcb`. The bare `rcb`
command runs the installed gem and may be out of sync with the
working tree.

    rcb-dev list                    # List all tasks
    rcb-dev <task>                  # Run a task
    rcb-dev --debug list            # Show cascade traversal
    rcb-dev clean_build             # Clean .build/
    rcb-dev build_all               # Full pipeline

Gem development:

    cd rcb/
    gem build rcb.gemspec
    gem install rcb-*.gem
    bundle exec rake test           # core unit tests (integration/feature tests open — see roadmap Phase 6)

## Workflow

- Integration branch: `master` (no remote configured).
- **Always work in feature branches.** Create one before starting:
  `git checkout -b feature/<descriptive-name>`. Never commit
  directly to `master`. Merge back when the work is done.
- `.build/` and `output/` are gitignored — never commit them.
- When a roadmap phase completes: (1) update the affected spec where it
  lives (gem → `docs/specs/`, pipeline → `pub/docs/dev/`), (2) add a
  Decision + what-was-done entry to `docs/history.md`, (3) remove the
  roadmap entry from `docs/plans/roadmap.md` (it is forward-only). The
  roadmap no longer holds completed phases or a decision log — those
  live in `docs/history.md`.

## Behaviour

### Before coding

- Pause and clarify. Don't accept a one-line brief — ask questions
  until you and the user share a clear picture of scope, behavior,
  and edge cases.
- Be critical. Surface unstated assumptions and gaps; don't just
  confirm.
- Present alternatives. If multiple reasonable interpretations or
  approaches exist, show them and let the user choose. Don't pick
  silently.
- Start coding only when the picture holds up.

### When editing existing code

- Surgical edits. Touch only what the task requires. Don't reformat,
  rename, or "improve" adjacent code. Match existing style even if
  you'd do it differently.
- Trace test. Every changed line should trace to the request. If you
  can't justify it, revert it.
- Clean up only your own orphans. Remove imports/variables your
  changes made unused. Leave pre-existing dead code alone — mention
  it instead.

### Code style

- Keep changes minimal. No abstractions, no error handling for
  impossible cases, no comments that restate the code.

## Where to look

| Topic | File |
|-------|------|
| Core RCB system (cascade, CFG, manifest, file tasks) | `docs/specs/core.md` |
| Pipeline architecture (how components fit together) | `pub/docs/dev/architecture.md` |
| Publishing pipeline (the demo workflow, stages, tools, assets) | `pub/README.md` |
| Editor workflow (guided article walkthrough) | `pub/docs/user/article-workflow.md` |
| Roadmap (forward-only — what's still open) | `docs/plans/roadmap.md` |
| History (decisions, what was built, completed phases) | `docs/history.md` |
