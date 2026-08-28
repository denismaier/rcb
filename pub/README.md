# JNDF Publishing Pipeline

**Status:** current as of 2026-08-28
**Built on:** rcb (see `../docs/specs/core.md`)

This directory is the production pipeline for JNDF: an academic
publishing pipeline that converts manuscripts (DOCX) to JATS XML,
HTML, and PDF. It doubles as rcb's runnable demo — the same pipeline
runs on synthetic fixtures (tracked in the repo) and on real
manuscripts (kept local, not committed).

### Repository layout: demo vs production

The pipeline (gem + `pub/_assets/` + journal-level config) is
single-source and tracked. Content is split by publisher under `pub/`:

```
pub/
  _assets/                         # shared pipeline DNA (xproc, xslt, context, rng, …) — tracked
  rcb.config.rb, rcb.rake          # root config + pipeline tasks — tracked
  bop/                             # real publisher — content LOCAL (gitignored)
    jndf/_assets/schematron/       # journal rules (DOI prefix 10.36950/jndf) — tracked
    jndf/{rcb.rake,metadata.yaml} # journal-level config — tracked
    jndf/volume_2026/              # real manuscripts at natural cascade depth — gitignored
  demoverlag/                      # demo publisher — fully tracked
    jds/                           # baseline demo journal (DOI prefix 10.5555/jds)
      volume_2026/<article>/       # synthetic fixture — builds green for anyone who clones
    dhr/                           # override demo journal (DOI prefix 10.5555/dhr)
      _assets/context/_layout_doc_fonts.tex   # journal-level font override (shadowing root)
      volume_2026/<article>/       # synthetic fixture
```

`.gitignore` keeps real content local with one line per publisher:
`pub/bop/*/volume_*/` ignores real volumes (journal-level config one
level up stays tracked). Demo content under `demoverlag/` is not
matched and is fully tracked. A second real publisher = a second line.

## Quickstart

```
cd pub/demoverlag/jds/volume_2026/jds-2026-001-mustermann
cp my-manuscript.docx source/<basename>.docx   # basename matches rcb.config.rb
cp figures/*.jpg source/images/
rcb-dev build_all
```

Outputs land in `output/{xml,html,pdf}/`. (To run on real production
content instead, work under `pub/bop/jndf/volume_<year>/<article>/` —
local, not committed.)

## Pipeline Overview

```
source/*.docx  -----+
                    +--> source_to_md --> md_final --+
source/*.md  ------+  (override branch)              |
(optional)                                           v
                                                md_to_xml
                                                     |
                          source/images/             v
                                |               xml_clean
                                v                    |
                         convert_images              v
                                |             validate_xml_rng
                                |                    |
                                |                    v
                                |          validate_xml_schematron
                                |                    |
                                |                    v
                                |                xml_typo
                                |                    |
                                |                    v
                                |                xml_final --> xml_publish --+--> xml_to_output --> output/xml/
                                |                    |                      |
                                |                    |                      +--> xml_to_zip    --> output/xml/<basename>.zip
                                |                    |
                                |                    +--> xml_to_html --> output/html/
                                |                    +--> xml_to_pdf  --> output/pdf/
                                v
                         images_to_output
                                |
                                v
                          .build/html/
                          output/html/
```

Each arrow is a Rake `file` task with mtime-based incremental rebuild.
See `rcb.rake` for declarations.

## Source Authoring

### Manuscript

The author's DOCX lives in `source/<basename>.docx`. The basename
comes from `rcb.config.rb` at the article level (see scaffold
section below). Images go in `source/images/` as separate files —
embedded images in DOCX are not supported.

### Front matter

Article front matter (title, authors, affiliations, abstract, tags,
DOI parts) is maintained in `metadata.yaml`, not derived from the DOCX.
An optional `subtitle:` field renders in both HTML (`<p class="subtitle">`
after the title) and PDF (mode-aware placement) — set it in
`metadata.yaml` and both renderers pick it up automatically. For the
guided metadata workflow see `docs/user/article-workflow.md`.

### Image Markers

Images are referenced from the manuscript with a plain-text marker
syntax that survives DOCX-to-MD conversion:

```
<<IMG: bild.jpg | caption: "Figure caption" | float: true | type: figure>>
```

Implemented as a Pandoc Lua filter
(`_assets/pandoc-lua-filters/image-markers.lua`) registered in the
`source_to_md` step. The filter rewrites markers to `pandoc.Image`
nodes, which Pandoc then renders as JATS `<fig>` elements with label
and caption.

Quirks:
- Path is filename only, no `images/` prefix.
- Word's auto-correct turns ASCII quotes into typographic ones; the
  filter normalizes UTF-8 before matching.
- `float:` accepts `true`/`false`; values matched as `%w+` then
  compared (Lua patterns don't support alternation in char classes).
- `--extract-media` is **not** passed to Pandoc — it would degrade
  the filter's image references to `.placeholder` files.

### MD Override

If a hand-edited `source/<basename>.md` exists, it replaces the
auto-generated MD. Useful when the converter produces messy output
that's faster to fix in MD than to repeatedly tweak the DOCX.

To create the override from the auto-generated MD, run
`rcb-dev promote_md` (depends on `source_to_md`, so the raw MD is
current). It refuses if `source/<basename>.md` already exists —
`promote` is a one-time step; edit the file directly afterwards.

The auto-conversion still runs and is written alongside as either:

| Filename | When |
|----------|------|
| `01-md-raw-<basename>.md.compare` | Override is current |
| `01-md-raw-<basename>.md.stale` | DOCX is newer than override (mtime) |

When stale, a warning fires through `RCB.warn` and shows in the
end-of-build summary. Compare the `.stale` file against the override
to decide whether to merge changes.

The stale check uses *origin* paths from the manifest, not the copies
in `.build/`, since copies always have fresh mtimes from the last
build.

### `extract_metadata`

Interactive task that pulls metadata fields from the source file via
Pandoc and merges them into the article's `metadata.yaml` after
showing a diff. Run when you want to pull metadata from the manuscript
(e.g. after a DOCX change); not needed when you maintain
`metadata.yaml` by hand.

Modes:
- Interactive (default): prompts `[y/N]` per change set.
- `rcb-dev --yes extract_metadata` or `CFG['extract_auto_apply'] = true`:
  apply without prompting.
- Fields listed in `_extract.protect:` in `metadata.yaml` are never
  overwritten on re-extraction. The list is yours to define — add
  fields once you've curated them and want to pin them. There is no
  default; with no `_extract.protect:`, re-extraction updates
  everything it extracts.

Not part of `build_all` because it's interactive and only needed
on metadata changes.

## Pipeline Stages

### Source Intake

| Task | Behavior |
|------|----------|
| `copy_source` | Copies `source/` -> `.build/source/` per-file |
| `source_to_md` | Dispatches by `CFG['source_format']` (today: `docx` only) |

`source_to_md` looks up `SOURCE_FORMATS[format]` for a register
function; placeholder branches for `odt`, `tex`, and `md` exist as
comments. Adding a format = add a register function and a hash entry.

### MD Processing

| Task | Tool | Behavior |
|------|------|----------|
| `md_final` | copy | Final MD (`99-md-final-<basename>.md`) ready for XML |

### XML Typography

| Task | Tool | Behavior |
|------|------|----------|
| `xml_typo` | Saxon (`transform`) + `_assets/xslt/_typography.xsl` | NNBSP/NBSP insertion in German abbreviations and locators after validation; skips `<front>` and code-like elements |

### XML Conversion

| Task | Tool | Behavior |
|------|------|----------|
| `md_to_xml` | Pandoc + Lua filters + JATS template | MD -> JATS XML (meta extraction, ref classification, attr conversion) |
| `xml_clean` | Morgana + `cleanup.xpl` | Cleanup via XProc pipeline (modular `p:xslt`-steps `_back-moves`/`_sections`/`_figures`/`_tables`/`_blocks`/`_anchor-default` + XProc-strip primitives); DTD-default-suppress at `<p:load>` |
| `validate_xml_rng` | `java -jar jing.jar` + JATS-RNG | Validate cleaned XML against JATS RNG schema; build fails on grammar errors |
| `validate_xml_schematron` | Saxon + SchXslt2 + `rules-journal.sch` | Validate against JNDF Schematron rules (article-type enum, DOI format); auto-transpiles `.sch` to `.xsl` |
| `xml_final` | copy | Final, validated XML *with* ConTeXt PIs |
| `xml_publish` | regex | Strip `<?context ...?>` PIs for OJS upload |

`xml_final` is the last step of the cleanup sub-pipeline and the canonical validated XML; the PDF/HTML/output stages all feed off it (directly or via `xml_publish`), so validation gates every downstream artifact automatically through the file-task DAG.

### Image Pipeline

| Task | Tool | Behavior |
|------|------|----------|
| `convert_images` | ImageMagick (`magick`) | TIFF->JPEG, others passthrough; resize down to `CFG['image_max_width']` (default 1200) |
| `images_to_output` | copy | Per-file copy to `.build/html/` and `output/html/` |

If `CFG['output_images']` is true, originals are also copied to
`output/images/` as a separate set.

ConTeXt receives the image directory via `--imagedir=<rel>` (relative
from `.build/pdf/`); the ConTeXt environment uses
`\getdocumentargument{imagedir}` to resolve image refs.

### Outputs

| Task | Tool | Output |
|------|------|--------|
| `xml_to_html` | Saxon + `jats2html.xsl` | `.build/html/<basename>.html` |
| `xml_to_html_test` | Saxon + `jats2html.xsl` + `galley.css` | `.build/html/test-<basename>.html` |
| `xml_to_pdf` | ConTeXt + `jats.tex` + `layout.tex` | `.build/pdf/<basename>.pdf` |
| `xml_to_pdf_test` | ConTeXt | `.build/pdf/<basename>-test.pdf` |
| `xml_to_output` | copy | `output/xml/<basename>.xml` (publish variant) |
| `xml_to_zip` | Info-ZIP (`zip`) + staging dir | `output/xml/<basename>.zip` — self-contained bundle (XML + web-images flat + originals in `original-images/`) |
| `html_to_output` | copy | `output/html/<basename>.html` |
| `html_test_to_output` | copy + galley.css | `output/html/test-<basename>.html` + `galley.css` |
| `pdf_to_output` | copy | `output/pdf/<basename>.pdf` |
| `pdf_test_to_output` | copy | `output/pdf/<basename>-test.pdf` |

`xml_to_zip` wird nur definiert, wenn der Artikel Bilder hat, und ist absichtlich nicht in `build_publish` — on-demand via `rcb-dev xml_to_zip`.

`xml_to_pdf` runs ConTeXt with `Open3.capture3(..., chdir: .build/pdf)`
so the subprocess (and only the subprocess) starts in `.build/pdf/`;
the Ruby parent's working directory is untouched. ConTeXt's environment
files are passed as `../_assets/context/jats.tex` and
`../_assets/context/layout.tex`, resolved relative to that subprocess cwd.

### Build Composites

| Task | Builds |
|------|--------|
| `build_publish` | Publishable XML + production HTML + production PDF + images |
| `build_test` | Test HTML (with CSS) + test PDF + images |
| `build_all` | Both |
| `init_build` | Just the workspace setup (dirs, assets, metadata) |

## File Naming (intermediate)

Two-digit prefix by stage; full basename as anchor. Lets glob/list
operations sort by stage naturally.

| Stage | File |
|-------|------|
| MD raw (out of source_to_md) | `.build/md/01-md-raw-<basename>.md` |
| MD final | `.build/md/99-md-final-<basename>.md` |
| MD compare/stale (override) | `01-md-raw-<basename>.md.compare` / `.stale` |
| XML raw | `.build/xml/01-xml-raw-<basename>.xml` |
| XML clean | `.build/xml/02-xml-clean-<basename>.xml` |
| XML RNG-validated | `.build/xml/03-xml-validated-<basename>.xml` |
| XML Schematron-validated | `.build/xml/04-xml-schematron-valid-<basename>.xml` |
| XML typo | `.build/xml/05-xml-typo-<basename>.xml` |
| XML final (with PIs) | `.build/xml/99-xml-final-<basename>.xml` |
| XML publish (no PIs) | `.build/xml/99-xml-publish-<basename>.xml` |
| XML zip bundle | `output/xml/<basename>.zip` |
| HTML production | `.build/html/<basename>.html` |
| HTML test | `.build/html/test-<basename>.html` |
| PDF production | `.build/pdf/<basename>.pdf` |
| PDF test | `.build/pdf/<basename>-test.pdf` |

Final outputs (`output/`) drop the stage prefix.

## Tools

| Tool | Used by | Required |
|------|---------|----------|
| Pandoc | `source_to_md`, `md_to_xml`, `extract_metadata` | yes |
| Saxon (`transform`) | `xml_clean`, `xml_to_html`, `xml_to_html_test`, `xml_typo`, `validate_xml_schematron` | yes |
| Jing (`java -jar jing.jar`) | `validate_xml_rng` | yes |
| ConTeXt (`context`) | `xml_to_pdf`, `xml_to_pdf_test` | yes |
| ImageMagick (`magick`) | `convert_images` | yes (when articles have images) |
| Info-ZIP (`zip`) | `xml_to_zip` (when article has images) | yes (when images present) |

## Assets

`_assets/` shadows from cascade levels (deeper level wins, see core
spec). Root `pub/_assets/` holds the shared pipeline DNA; each journal
adds `_assets/schematron/` (DOI-prefix rules) and may shadow
`_assets/context/` (dhr's font override lives here).

| Subdir | Contents |
|--------|----------|
| `pandoc-templates/` | Pandoc output templates (`jats_publishing.template`, metadata extractors) |
| `pandoc-lua-filters/` | Lua filters: `image-markers.lua` (source_to_md), `author-notes-to-meta.lua`, `abstract-to-meta.lua`, `auto-classify-refs.lua`, `auto-classify-app-figures.lua`, `html-tables.lua`, `pandoc-list-table.lua`, `list-table.lua`, `versify.lua`, `classes-to-attr.lua` (md_to_xml) |
| `xslt/` | `jats2html.xsl` (XML -> HTML), `_typography.xsl` (typographic replacements) |
| `xproc/` | `cleanup.xpl` + modular `_*.xsl` steps (`_back-moves`, `_sections`, `_figures`, `_tables`, `_blocks`, `_anchor-default`) — the `xml_clean` pipeline |
| `context/` | `jats.tex` (ConTeXt JATS module), `layout.tex` (page layout) + modular `_layout_*.tex` (Phase 5: `_layout_doc_*` page/flow/font setup, `_layout_element_*` per-element layouts) |
| `css/` | `galley.css` (test HTML stylesheet) |
| `jats-dtd/` | JATS DTD files + catalogs (~1.9 MB) |
| `jats-rng/` | JATS Publishing 1.2 RNG schemas (entry: `JATS-journalpublishing1.rng`) |
| `schematron/` | Journal-spezifische Schematron-Regeln (`rules-journal.sch`, DOI-Prefix pro Journal) — auf Journal-Ebene (`<journal>/_assets/schematron/`), nicht root |
| `metadata/` | `metadata-template-article.yaml` for `init_article` |

## Adding a New Article

`init_article` (run from a volume directory) scaffolds a new article
dir with `rcb.config.rb`, `rcb.rake` (with `full_article_info` task),
`metadata.yaml` from template, and `source/` subdir:

```
cd pub/demoverlag/jds/volume_2026             # demo/fixture volume (tracked)
# or: cd pub/bop/jndf/volume_<year>           # real production volume (local)
rcb-dev init_article
# prompts for article number and author last name
# basename becomes <abbrev>-<year>-<num>-<author-slug>
```

After scaffolding: drop the DOCX in `<basename>/source/`, fill
`metadata.yaml`, run `build_test` to review, then `build_all`. For the
full guided walkthrough (including when `extract_metadata` is needed and
the MD-override workflow), see `docs/user/article-workflow.md`.

## Code Pointers

| Concern | File |
|---------|------|
| Pipeline declaration | `rcb.rake` |
| Build defaults | `rcb.config.rb` |
| Image markers (Lua) | `_assets/pandoc-lua-filters/image-markers.lua` |
| XProc cleanup | `_assets/xproc/cleanup.xpl` (+ modular `_*.xsl` steps) |
| XSLT HTML | `_assets/xslt/jats2html.xsl` |
| XSLT Typography | `_assets/xslt/_typography.xsl` |
| ConTeXt environment | `_assets/context/jats.tex`, `_assets/context/layout.tex` |
| Article CFG (basename, source_format) | `pub/bop/jndf/volume_NN/article_NN/rcb.config.rb` |
| Scaffold | `init_article` task in `rcb.rake` |
