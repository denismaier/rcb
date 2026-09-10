# RCB Core

**Status:** current as of 2026-09-10
**Reference:** `rcb/lib/rcb.rb` (274 lines), `rcb/exe/rcb`

## Overview

RCB (Ruby Cascade Build) is a small Rake-based build system that
loads configuration and tasks from a directory cascade. It relocates
to the nearest contributing cascade level if the cwd is not a level
itself, then walks upward until it finds `.rcbroot`, collecting
per-level files in path order. The result is a single
unified Rake invocation whose configuration and task definitions
contribute from each cascade level.

The gem itself is small (~230 lines): a cascade walker, file scanners,
a manifest writer, a warnings framework, and a CLI wrapper. Pipeline
tasks (the actual work) live in user code (`rcb.rake` files at any
cascade level).

## Cascade

### Traversal

```
article_01/        <- cwd
   |
volume_01/         <- rcb.rake (optional)
   |
journal/           <- rcb.rake (optional)
   |
pub/               <- rcb.rake + .rcbroot -> STOP
```

`.rcbroot` is an empty marker file at the cascade root. Without it,
rcb refuses to run.

### Start Resolution

Before the walk, `resolve_start(cwd)` decides where the cascade
should start. It returns the project root and the start directory:

1. Ascend to `.rcbroot`. Not found → rcb refuses to run.
2. A directory is **buildable** if it contains at least one per-level
   file (`rcb.rake`, `rcb.config.rb`, or `metadata.yaml`).
3. If the cwd is buildable, it is the start directory (no-op, behavior
   identical to running there directly).
4. Otherwise rcb ascends to the nearest buildable ancestor and
   `Dir.chdir`s there, printing `→ running in <dir>`. If no ancestor
   up to the root is buildable, rcb refuses to run.

Consequence: invoking rcb from a non-level directory (e.g. an
article's `source/`) relocates the build to the owning level instead
of writing `.build/` into the wrong place. The relocation is purely
process-local — the caller's shell stays where it is. Whether the
*relocated* level makes sense for a given task is not the gem's
concern; task-level guards (`require_article` in the demo pipeline)
reject invocations that lack the context they need.

`find_cascade(start_dir, root)` is the pure walker underneath: given
the resolved start and root, it collects any `rcb.rake` it finds and
records the directory list. The full path is exposed to user code as
`$rcb_cascade_dirs` (root-first, frozen).

Reference: `rcb/lib/rcb.rb:52-99` (resolve_start, find_cascade),
`rcb/lib/rcb.rb:191-198` (run wiring).

### Two-Phase Loading

rcb loads cascade files in two phases to keep `CFG` populated before
any task definition runs:

1. **Phase 1 — Configs.** All `rcb.config.rb` files load root-first.
   They mutate the toplevel `CFG` hash.
2. **Phase 2 — Rakefiles.** All `rcb.rake` files load root-first.
   They define tasks and read `CFG` at definition time.

If config and tasks lived in the same file, deep-cascade tasks would
read CFG values not yet populated by their own level's setup. The
two-phase split avoids that.

Reference: `rcb/lib/rcb.rb:208-229`.

### Per-Level Files

Each cascade directory may contain:

| File | Purpose |
|------|---------|
| `rcb.config.rb` | Build-config. Contributes to `CFG`. Optional. |
| `rcb.rake` | Tasks. Defines or overrides Rake tasks. Optional. |
| `metadata.yaml` | Content metadata (used by application code, not by rcb itself). Optional. |
| `_assets/` | Asset directory (subject to shadowing). Optional. |

A level needs neither config nor rakefile if it has nothing to
contribute. Journal and volume levels in the demo are pure structural
nesting with only `metadata.yaml`.

One derived role: any of `rcb.rake`, `rcb.config.rb`, or
`metadata.yaml` marks a directory as buildable, i.e. a valid
invocation point (see Start Resolution above). A directory with
none of the three — `source/`, `_assets/`, pure grouping folders —
is not a valid invocation point; rcb relocates out of it.

## Configuration (CFG)

`CFG` is a plain Ruby `Hash`, defined at toplevel in `rcb.rb` so every
loaded file sees it without qualification:

```ruby
CFG = {}  # rcb.rb:14
```

The hash is populated by `rcb.config.rb` files during Phase 1. Lower
cascade levels can override values from higher levels. Tasks in
`rcb.rake` files read `CFG` at load time:

```ruby
# pub/rcb.config.rb
CFG['build_dir']  = '.build'
CFG['output_dir'] = 'output'

# article_01/rcb.config.rb
CFG['basename']      = 'jndf-2026-001'
CFG['source_format'] = 'docx'
```

**Convention:** `CFG` is for *build configuration* (paths, tool
settings, feature flags). *Content metadata* (titles, authors, ISSNs)
belongs in `metadata.yaml`. Keep them separate.

## Manifest

Before Phase 2, rcb writes a manifest to `.build/manifest.yaml`
containing the resolved cascade state.

### Contents

| Key | Source |
|-----|--------|
| `cascade` | `$rcb_cascade_dirs` (root-first array of directory paths) |
| `config` | `CFG.to_h` after Phase 1 |
| `assets` | `scan_assets` — `{rel_path => origin}`, deepest level wins |
| `sources` | `scan_source` — files in deepest level's `source/` |
| `metadata` | `scan_metadata` — list of every `metadata.yaml` in the cascade |

### Why before Phase 2

`rcb.rake` files can call `RCB.load_manifest` at definition time to
discover what they need to build. Example: the demo's image pipeline
loops over `manifest['sources']`, filters by extension, and defines
one file task per image. Without the manifest, each rakefile would
need its own filesystem walks.

Reference: `rcb/lib/rcb.rb:216-229`.

### Scanners

| Function | Returns |
|----------|---------|
| `scan_assets(dirs, name)` | `{rel_path => origin}` from all `_assets/` dirs, deepest wins |
| `scan_source(article_dir)` | `{rel_path => origin}` from deepest level's `source/` |
| `scan_metadata(dirs)` | Array of `metadata.yaml` paths, all levels |
| `scan_configs(dirs)` | Array of `rcb.config.rb` paths, all levels |

`.bak` files and dotfiles are skipped.

## File Tasks Pattern

rcb encourages declaring pipeline steps as Rake `file` tasks rather
than imperative `task` blocks. Benefits:

- **Incremental builds.** Rake skips a step when its target is newer
  than its inputs (mtime check).
- **Explicit DAG.** Each step declares its inputs; Rake resolves
  dependencies automatically.
- **Manifest-driven.** Targets can be derived from `RCB.load_manifest`
  rather than hardcoded.

Two helpers generate file tasks for cascade-discovered files:

- `generate_asset_file_tasks(assets)` — one file task per asset, copies
  `_assets/{rel}` to `.build/_assets/{rel}`. Returns target list.
- `generate_source_file_tasks(sources)` — same for `source/`.

User code wires these into named alias tasks (`prepare_assets`,
`copy_source`).

For application-level steps, the demo uses a hash-declaration pattern:

```ruby
md_typo = {
  in:  source_to_md[:out],
  out: (BUILD_DIR / "md/02-md-typo-#{basename}.md").to_s,
  desc: "Apply typography replacements",
}

file md_typo[:out] => [md_typo[:in], ...] do |t|
  ...
end

task :md_typo => [md_typo[:out]]
```

The hash declaration is convention, not a rcb feature. See
`pub/rcb.rake` for full examples.

## Asset Shadowing

Files in `_assets/` are visible to all cascade levels. When the same
relative path exists at multiple levels, the **deepest level wins**.

```
pub/_assets/xslt/cleanup.xsl          <- base
journal/_assets/xslt/cleanup.xsl       <- overrides publisher
article_01/_assets/xslt/cleanup.xsl    <- overrides journal
```

Implementation: `scan_assets` iterates root-first and overwrites map
entries; later (deeper) iterations win. Each entry becomes a
`Rake::FileTask` that copies origin to `.build/_assets/{rel}`. User
tasks reference assets by their `.build/_assets/...` path, so they
see the resolved (shadowed) version.

Reference: `rcb/lib/rcb.rb:101-118, 156-168`.

## Warnings Framework

Non-fatal warnings get collected and summarized at process exit:

```ruby
RCB.warn("STALE OVERRIDE: #{file} is newer than ...")
```

`RCB::WARNINGS` is a module-level array. `RCB.warn(msg)` appends.
An `at_exit` block prints a boxed summary if any warnings accumulated.

The `at_exit` block runs even on exception, so warnings are visible
when a build aborts. Designed for situations where stopping the build
would be over-strict but the user should still see the issue (the
canonical case is the demo's MD-override stale detection).

Reference: `rcb/lib/rcb.rb:33-38, 267-274`.

## CLI

Two entry points:

- **`rcb`** — installed gem. Run from end users / production.
- **`rcb-dev`** — in-repo wrapper (`rcb-dev` for bash/Git Bash,
  `rcb-dev.bat` for Windows cmd/PowerShell) that runs RCB from the
  working tree without `gem install`. Self-resolving (finds its own
  location via `BASH_SOURCE` / `%~dp0`), so it works from any clone and
  any cwd once on PATH. Use during development. See
  [`docs/setup.md`](../setup.md) for how to put it on PATH.

Flags:

| Flag | Effect |
|------|--------|
| `--debug` | Prints cascade traversal and rakefile load order |
| `--yes` | Auto-accepts interactive prompts (e.g. `extract_metadata`) |

Common invocations:

```
rcb-dev list           # List all tasks (default if no task given)
rcb-dev <task>         # Run a task
rcb-dev --debug list   # Show cascade
```

## Extension Points

### Adding a New Cascade Level

1. Create directory under the parent level.
2. Add `rcb.config.rb` if the level has CFG contributions (optional).
3. Add `rcb.rake` if it has tasks or overrides (optional).
4. Add `_assets/` if it shadows assets (optional).

### Adding a New Pipeline Step

In an `rcb.rake` (typically the publisher's, since pipelines are
publisher-level concerns):

```ruby
my_step = {
  in:  prev_step[:out],
  out: (BUILD_DIR / 'something').to_s,
  desc: "Description",
}
file my_step[:out] => [my_step[:in]] do |t|
  # work, write to t.name
end
task :my_step => [my_step[:out]]
```

### Overriding a Task at a Lower Level

Rake redefines tasks when the same name is declared again. Lower-level
files load later, so re-declaring a task in a deeper-level rakefile
replaces the parent's version:

```ruby
# journal_2/rcb.rake
task :xml_to_html do
  # journal-specific HTML rendering
end
```

Use cases: per-journal branding, per-volume skipping (no-op task),
per-article custom processing.

## Error Handling

Tasks should raise descriptive errors and check tool exit status:

```ruby
stdout, stderr, status = Open3.capture3('pandoc', src, '-o', dst)
raise "Pandoc failed: #{stderr}" unless status.success?
```

Use `Open3.capture3` with array form (not string) to avoid shell
injection. Use `RCB.warn` for non-fatal issues that shouldn't abort
the build but should surface to the user.
