# Setup

How to get RCB running from a fresh clone. The gem itself is plain Ruby;
the publishing pipeline under `pub/` drives several external tools.

## 1. Install Ruby (≥ 3.0)

| OS | How |
|----|-----|
| Windows | [`rv`](https://github.com/rv-ruby/rv) (Ruby version manager) **or** [RubyInstaller](https://rubyinstaller.org) (tick "Add Ruby to PATH") |
| macOS | `brew install ruby` (or `rbenv` / `asdf`) |
| Linux | `rbenv` / `asdf`, or your distro's `ruby` package |

Verify, then ensure Bundler is present (RubyInstaller ships it; otherwise
`gem install bundler`):

```bash
ruby -v
bundle -v
```

## 2. External tools (the pipeline only)

Only needed to run the `pub/` publishing pipeline. The gem alone
(cascade, CFG, manifest, file tasks) needs nothing beyond Ruby + Rake.

| Tool | Used by | Install hint |
|------|---------|--------------|
| [Pandoc](https://pandoc.org) | `source_to_md`, `md_to_xml` | download; `CFG['pandoc_cmd']` |
| [Morgana XProc](https://www.xml-project.com/morganaXProc-ix.html) | `xml_clean` (XProc pipeline) | download; needs the Saxon HE JAR in its `_lib/`; `CFG['xproc_cmd']` |
| [Saxon HE](https://www.saxonica.com/download/java.xml) | `xml_typo`, `xml_to_refs`, `xml_to_html`, `validate_xml_schematron`, SchXslt2 transpile | download the HE JAR; `CFG['saxon_he_jar']`, `CFG['xslt_cmd']` |
| [SchXslt2](https://github.com/schxslt/schxslt2) | Schematron transpile | clone/download; `CFG['schxslt2_xsl']` |
| [jing](https://github.com/relaxng/jing-trang) | `validate_xml_rng` (JATS-RNG) | build/download; `CFG['jing_jar']` |
| [ConTeXt](https://wiki.contextgarden.net/Installation) | `xml_to_pdf` | install; `CFG['context_cmd']` |
| [ImageMagick](https://imagemagick.org) | `convert_images` | install; `magick` on PATH (`CFG['image_tool']`) |
| [Info-ZIP](https://infozip.sourceforge.net) | `xml_to_zip` | `CFG['zip_cmd']` (preinstalled on most systems) |
| Java | Saxon, Morgana, jing (all JAR-based) | a JRE is enough; `CFG['java_cmd']` |

The JATS DTD and RNG bundles ship in the repo under
`pub/_assets/jats-dtd/` and `pub/_assets/jats-rng/` — no download needed.

## 3. Install the gem's Ruby dependencies

```bash
cd rcb/
bundle install
```

This installs `rake` (and `minitest` for the tests). After this, `rake` is
available to the `rcb-dev` wrapper via RubyGems.

## 4. Put rcb-dev on PATH

RCB ships two self-resolving wrappers at the repo root — they find their
own location, so they work from any clone and any cwd once on PATH:

- `rcb-dev` — bash / Git Bash
- `rcb-dev.bat` — Windows cmd / PowerShell

They run RCB straight from the working tree (no `gem install`), so code
changes are immediately active. Pick one:

```bash
# Unix / Git Bash: symlink into a dir that's already on PATH
ln -s "$PWD/rcb-dev" ~/.local/dev-bin/

# Windows (PowerShell, current session): add the repo root to PATH
$env:PATH = "$PWD;$env:PATH"
```

On Windows cmd/PowerShell, calling `rcb-dev` resolves to `rcb-dev.bat`
automatically. For a permanent setup, add the repo root to your user
PATH or set up an alias.

## 5. Set tool paths (only if not on PATH)

`pub/rcb.config.rb` defaults to bare tool names, assuming everything is
on PATH (`pandoc`, `magick`, `morgana`, `context`, `zip`, `java`,
`transform`) and bare JAR/XSL names (`saxon-he.jar`, `jing.jar`,
`schxslt2/transpile.xsl`). If your layout differs — e.g. a pinned Pandoc
version or specific JAR locations — override in one of two ways:

**a) Local override file (recommended for persistent setups):**

```bash
cp pub/rcb.config.local.example.rb pub/rcb.config.local.rb
# then edit pub/rcb.config.local.rb and uncomment/set your paths
```

`rcb.config.local.rb` is gitignored and loads at the end of
`rcb.config.rb`, so it wins over the defaults.

**b) Environment variables (good for CI / headless):**

```bash
export RCB_PANDOC_CMD=/opt/pandoc/3.10.2/pandoc
export RCB_SAXON_HE_JAR=/opt/saxon/saxon-he-12.5.jar
export RCB_JING_JAR=/opt/jing/bin/jing.jar
export RCB_SCHXSLT2_XSL=/opt/schxslt2/transpile.xsl
export RCB_XPROC_CMD=/opt/morgana/morgana
export RCB_CONTEXT_CMD=/opt/context/bin/context
export RCB_ZIP_CMD=/usr/bin/zip
export RCB_JAVA_CMD=/opt/jdk/bin/java
export RCB_XSLT_CMD=/opt/saxon/transform
```

ENV vars win over the bare defaults; the local file wins over both.

## 6. Run a first build

From any directory within the cascade — try the demo article, which is
tracked and builds green for anyone:

```bash
cd pub/demoverlag/jds/volume_2026/jds-2026-001-mustermann
rcb-dev list          # list all tasks (default if no task given)
rcb-dev build_test    # build test HTML + PDF
rcb-dev build_all     # full pipeline (publish + test outputs)
rcb-dev --debug list  # show the cascade traversal + load order
```

Outputs land in `output/{xml,html,pdf}/`. See
[`pub/README.md`](../pub/README.md) for per-stage behavior, and
[`docs/specs/core.md`](specs/core.md) for the gem's extension points.