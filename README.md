# RCB — Ruby Cascade Build

**RCB** is a lightweight cascading build system on Rake. Configuration and
tasks live in `rcb.config.rb` / `rcb.rake` files at each level of a directory
cascade; RCB walks upward from the working directory to `.rcbroot` and unifies
them into one Rake invocation. Deeper levels override shallower ones.

The repository ships one pipeline on top of the gem — an academic
publishing pipeline (`pub/`: DOCX → JATS XML → HTML/PDF) that doubles as
RCB's runnable demo.

## Two parts

| Part | What | Where |
|------|------|-------|
| **The gem** | Generic cascade build: walker, `CFG`, manifest, file-task helpers, warnings, CLI. ~230 lines. | `rcb/lib/rcb.rb` — spec: [`docs/specs/core.md`](docs/specs/core.md) |
| **The pipeline** | The concrete steps (DOCX → JATS → HTML/PDF): Rakefile + assets (XProc, XSLT, ConTeXt, Lua, RNG/Schematron). | `pub/rcb.rake` + `pub/_assets/` — reference: [`pub/README.md`](pub/README.md) |

The gem knows no pipeline steps — it provides only the mechanism. The
pipeline is pure user code of the gem.

## Where to go next

**I want to use the pipeline (edit an article):**
- [`pub/docs/user/article-workflow.md`](pub/docs/user/article-workflow.md) —
  guided editor walkthrough (scaffold → metadata → build).
- [`pub/README.md`](pub/README.md) → Quickstart — run a build in 4 lines.

**I want to understand / develop the system:**
- [`docs/specs/core.md`](docs/specs/core.md) — the gem (cascade, CFG,
  manifest, file tasks, extension points).
- [`pub/docs/dev/architecture.md`](pub/docs/dev/architecture.md) — how the
  pipeline's components fit together (XProc cleanup, ConTeXt, Lua chain,
  validation).
- [`docs/history.md`](docs/history.md) — decisions and what was built.
- [`docs/plans/roadmap.md`](docs/plans/roadmap.md) — what's still open.

## Quick start

```bash
# Install the gem (or use rcb-dev, below)
cd rcb/ && gem build rcb.gemspec && gem install rcb-*.gem

# From any directory within the cascade
# (e.g. pub/demoverlag/jds/volume_2026/<article>/)
rcb-dev list              # List all tasks
rcb-dev build_test        # Build test HTML + PDF
rcb-dev build_all         # Full pipeline (publish + test)
rcb-dev --debug list      # Show cascade traversal
```

Use `rcb-dev` (the dev wrapper) during development — it runs RCB from the
working tree without `gem install`, so changes are immediately active. The
bare `rcb` command runs the installed gem and may be out of sync.

## Architecture

### Cascade traversal

`rcb` walks upward from the current directory until it finds `.rcbroot`,
collecting per-level files in path order:

```
article_01/            # rcb.config.rb (basename, source_format), metadata.yaml, source/
       ↓
volume_01/             # metadata.yaml (optional rcb.rake)
       ↓
journal/               # metadata.yaml + _assets/ (Schematron, font override)
       ↓
pub/                   # rcb.rake (pipeline) + rcb.config.rb (defaults) + _assets/  ← .rcbroot (STOP)
```

### Two-phase loading

1. **Configs:** all `rcb.config.rb` files load root-first, mutating the
   shared `CFG` hash.
2. **Manifest:** RCB writes `.build/manifest.yaml` (cascade, config, assets,
   sources, metadata) — the single source tasks read from.
3. **Rakefiles:** all `rcb.rake` files load root-first, defining tasks that
   read `CFG` and the manifest at load time.

Deeper levels override shallower ones — both config values (`CFG` hash,
last write wins) and tasks (Rake redefines a task when the same name is
declared again; deeper loads later).

### Key concepts

- **`.rcbroot`** — empty marker file at the cascade root.
- **`CFG`** — shared configuration `Hash` (build config: paths, tools,
  flags). Content metadata (titles, authors) lives in `metadata.yaml`,
  kept separate.
- **Manifest** — resolved cascade state written to `.build/manifest.yaml`;
  tasks discover inputs from it instead of walking the filesystem.
- **File tasks** — pipeline steps are Rake `file` tasks with declared
  inputs; Rake resolves the DAG and skips steps whose target is newer than
  their inputs (mtime → incremental builds).
- **Asset shadowing** — files in `_assets/` are visible to all levels; the
  deepest level wins for the same relative path.

## Project structure

```
rcb-cascade/
├── rcb/                  # The gem
│   ├── exe/rcb           # CLI entry point
│   ├── lib/rcb.rb        # Cascade, manifest, file tasks, warnings (~230 lines)
│   └── rcb.gemspec
├── docs/                 # generic / repo-level documentation
│   ├── specs/core.md     # gem spec
│   ├── plans/roadmap.md  # forward-only roadmap
│   └── history.md        # decisions + build history
├── pub/                  # the pipeline (cascade root)
│   ├── .rcbroot          # root marker
│   ├── rcb.rake          # pipeline task declarations
│   ├── rcb.config.rb     # build defaults
│   ├── _assets/          # shared pipeline DNA (xproc, xslt, context, rng, lua, …)
│   ├── README.md         # pipeline reference
│   ├── docs/{user,dev}/  # pipeline guides (editor workflow / architecture)
│   ├── bop/              # real publisher (content gitignored)
│   │   └── jndf/         # journal (DOI prefix 10.36950/jndf)
│   └── demoverlag/       # demo publisher (tracked fixtures)
│       ├── jds/          # baseline demo journal
│       └── dhr/          # override demo journal (font shadowing)
└── README.md
```

`.build/` and `output/` are gitignored — never commit them. Real content
(`pub/bop/*/volume_*/`) is gitignored; demo content under `demoverlag/` is
tracked and builds green for anyone who clones.

## Available tasks

`rcb-dev list` enumerates all tasks (named tasks plus one file task per
asset/source file). The named tasks (~38):

```
init_article  extract_metadata  promote_md      # authoring / scaffold
source_to_md  md_final          md_to_xml        # MD intake + conversion
xml_clean     validate_xml_rng validate_xml_schematron  xml_typo  # XML cleanup + validation
xml_final     xml_publish       xml_to_output    xml_to_refs  refs_to_output  # final XML + refs
xml_to_html   xml_to_html_test  html_to_output  html_test_to_output        # HTML
xml_to_pdf    xml_to_pdf_test   pdf_to_output   pdf_test_to_output         # PDF
convert_images  images_to_output  xml_to_zip                              # images + bundle
build_test    build_publish     build_all        init_build  clean_build   # composites
copy_source   prepare_assets    prepare_metadata  validate_config          # setup
article_info  journal_info      volume_info      full_article_info         # info
```

See [`pub/README.md`](pub/README.md) for per-stage behavior, tools, and
assets.

## Development

RCB is intentionally minimal: no `RCB::Cascade` class, no `RCBContext` —
just traversal + loading with Rake's built-in `load`. See
[`docs/specs/core.md`](docs/specs/core.md) for extension points (new
cascade level, new pipeline step, task override, new source format).

```
cd rcb/
gem build rcb.gemspec
gem install rcb-*.gem
bundle exec rake test          # core unit tests (see roadmap Phase 6 for the rest)
```

## License

Same as parent project.