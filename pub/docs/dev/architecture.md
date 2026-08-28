# Pipeline-Architektur

**Status:** current as of 2026-08-28
**Audience:** dev — wer RCB versteht (siehe `docs/specs/core.md`) und jetzt
wissen will, wie die konkrete JNDF-Pipeline darauf aufbaut und wie ihre
Komponenten zusammenhängen.

Diese Seite ist die Komponenten-Übersicht. Aufgaben- und Tool-Details
stehen in `pub/README.md`; die Gem-Mechanik (Cascade, Manifest, File-Task-
Pattern) in `docs/specs/core.md`. Hier wird das *Zusammenspiel* beschrieben.

---

## Zwei-Teiliges System

RCB ist Schicht-Design: ein kleines generisches Build-Gem und eine konkrete
Pipeline, die darauf läuft.

| Schicht | Was | Wo |
|---------|-----|------|
| **RCB-Gem** | Generisches Cascade-Build: Cascade-Walker, Manifest, File-Task-Pattern, Warnings, CLI. ~230 Zeilen. | `rcb/lib/rcb.rb` — siehe `docs/specs/core.md` |
| **Pipeline** | Die konkreten Schritte (DOCX → JATS → HTML/PDF): Rakefile-Deklaration + Asset-Dateien (XProc, XSLT, ConTeXt, Lua, RNG/Schematron). | `pub/rcb.rake` + `pub/_assets/` |

Das Gem kennt keine Pipeline-Schritte — es liefert nur die Mechanik
(Cascade-Traversal, CFG-Hash, Manifest, File-Task-Helfer, Warnings). Die
Pipeline lebt vollständig in `pub/` und ist "nur" Anwender-Code des Gems.

---

## Cascade-Ebenen

Vier Ebenen, jede kann `rcb.config.rb`, `rcb.rake`, `metadata.yaml`,
`_assets/` beitragen (alles optional):

```
pub/         <- rcb.rake + .rcbroot -> STOP   (Pipeline-Deklaration, Shared-Assets)
  journal/   <- metadata.yaml + ggf. _assets/ (Schematron-Regeln, Font-Override)
    volume/  <- metadata.yaml + ggf. rcb.rake (Volume-PDF-Pipeline)
      article/ <- rcb.config.rb (basename, source_format) + metadata.yaml + source/
```

**Tiefere Ebene gewinnt** bei Schatten (Asset-Shadowing) und Task-Override
(Rake redefiniert bei Namensgleichheit; tiefere lädt später). Siehe
`core.md` → Asset Shadowing / Overriding a Task.

### Demo vs. Produktion

| Verlag | Pfad | Trackt? |
|--------|------|---------|
| Produktion | `pub/bop/<journal>/` | Journal-Config (rcb.rake, metadata.yaml, Schematron) getrackt; `volume_*/` gitignored (echte Manuskripte) |
| Demo | `pub/demoverlag/<journal>/` | vollständig getrackt (synthetische Fixtures, baut grün für jeden Clone) |

`.gitignore`: `pub/bop/*/volume_*/` hält echte Inhalte lokal, eine Zeile
pro Verlag. Journal-Ebene eine Stufe drüber bleibt getrackt. Ein zweiter
echter Verlag = eine zweite Zeile. (`pub/README.md` → Repository layout.)

---

## Build-Lifecycle

1. **Cascade-Traversal:** von cwd aufwärts bis `.rcbroot`; sammelt
   `rcb.config.rb` + `rcb.rake` root-first. (`core.md` → Cascade)
2. **Phase 1 — Configs:** alle `rcb.config.rb` laden root-first, mutieren
   `CFG`. (`core.md` → Two-Phase Loading)
3. **Manifest:** rcb schreibt `.build/manifest.yaml` (cascade, config,
   assets, sources, metadata). Single-Source für alle Tasks. (`core.md`
   → Manifest)
4. **Phase 2 — Rakefiles:** alle `rcb.rake` laden root-first, definieren
   Tasks, lesen `CFG` + `RCB.load_manifest` zur Definitionszeit.
5. **File-Task-DAG:** jede Stufe ist ein Rake-`file`-Task mit deklarierten
   Inputs → Rake löst Abhängigkeiten auf, baut inkrementell (mtime: Target
   neuer als Inputs → überspringen). (`core.md` → File Tasks Pattern)

---

## Pipeline-Komponenten-Map

Die Stufenkette (verkürzt aus `pub/README.md` → Pipeline Overview):

```
source/*.docx --+--> source_to_md --+--> md_to_xml --> xml_clean --> validate(rng+schematron)
source/*.md   --+   (override)     |                 |                |
                                   |                 v                v
                                   |            xml_typo -----> xml_final --+--> xml_to_html
                                   |                                |       +--> xml_to_pdf
                                   v                                |       +--> xml_to_output/xml_to_zip
                            convert_images --> images_to_output <---+
```

Je Stufe das Tool und die Asset-Datei (Asset-Pfade relativ zu `pub/_assets/`):

| Stufe | Tool | Asset |
|-------|------|-------|
| `source_to_md` | Pandoc | `pandoc-lua-filters/image-markers.lua` |
| `md_to_xml` | Pandoc + Lua-Kette | `pandoc-templates/jats_publishing.template` + 8 Lua-Filter |
| `xml_clean` | Morgana (XProc) | `xproc/cleanup.xpl` + `_*.xsl`-Steps |
| `validate_xml_rng` | Jing | `jats-rng/JATS-journalpublishing1.rng` |
| `validate_xml_schematron` | Saxon + SchXslt2 | `<journal>/_assets/schematron/rules-journal.sch` |
| `xml_typo` | Saxon | `xslt/_typography.xsl` |
| `xml_to_html` | Saxon | `xslt/jats2html.xsl` |
| `xml_to_pdf` | ConTeXt | `context/jats.tex` + `context/layout.tex` (+ `_layout_*.tex`) |

`xml_final` ist das validierte Canonical-XML; alle Downstream-Artefakte
(HTML/PDF/output/zip) hängen direkt oder via `xml_publish` daran →
Validierung gate-t automatisch jeden Downstream-Output über den DAG.

---

## Komponenten-Tiefen

### XProc-Cleanup (`xml_clean`)

`cleanup.xpl` ist eine modulare XProc-Pipeline. Cleanup-Logik steckt in
zwei Sorten von Steps:

- **`p:xslt`-Steps** mit modularen Stylesheets: `_back-moves.xsl`
  (sec/ref-list/app-figures zurück in `<back>`), `_sections.xsl`,
  `_figures.xsl`, `_tables.xsl`, `_blocks.xsl`, `_anchor-default.xsl`.
- **XProc-Primitive** für reines Stripping: `p:unwrap`, `p:delete`,
  `p:viewport` (PI-Survival, Leerraum-Entfernung) — ohne eigene XSLT-Datei.

**DTD-Default-Suppress:** am `<p:load>` wird per Option das
DTD-Default-Auffüllen unterdrückt, damit nicht-validierte Defaults die
Cleanup-Schritte verfälschen. Verifiziert für Morgana (Saxon im `_lib/`);
Calabash-Äquivalent offen (Roadmap Phase 20c, nicht blockierend).

**`nonumheadings`-Toggle:** ein CFG-Flag (`CFG['nonumheadings']`) treibt
XSLT *und* ConTeXt gemeinsam — die Section-Nummerierung wird in beiden
Renderern koordiniert an/ausgeschaltet, nicht pro Renderer konfiguriert.
(Herkunft: legacy-Makefile-Verhalten; siehe `docs/history.md`.)

**Refs-Layering ist bewusst gewachsen:** die Kette
`auto-classify-refs.lua` → `classes-to-attr.lua` (`sec-type="ref-list"`)
→ `_back-moves.xsl` (`<sec>`→`<ref-list>`, inkl. wrapper/nested/shorthands)
löst das *Mehrebenen-Problem* (Quellen + Sekundärliteratur + Siglen als
mehrere ref-lists), das ein älterer direkter Überschrift→ref-list-Filter
nicht abdeckte. **Nicht vereinfachbar ohne Rücknahme in den Broken-Zustand.**
(Siehe `docs/history.md`; CSL bewusst *nicht* gewollt — kein Blocker.)

**App-Figures:** `.app-figures`-Klasse → Appendix-Figuren wandern über eine
3-Stufen-Kette in den Anhang: `classes-to-attr.lua` (Klasse→Attribut) →
`_back-moves.xsl` (Strukturverschiebung) → Templates.

### ConTeXt (`xml_to_pdf`)

ConTeXt-Setup besteht aus zwei Dateien plus Override-Modulen:

- **`jats.tex`** — das XML→TeX-Mapping (`\xmlsetsetup` pro JATS-Element).
  Element-awareness ist hier nötig (z.B. Typografie "S.5" braucht
  Element-Kontext, kein Plain-String) — deshalb ConTeXt statt Pure-String-
  Filter; XSLT/Plain-String bewusst ausgeschlossen.
- **`layout.tex`** — der Driver: lädt `jats.tex` als `\environment` und
  reiht ~21 `_layout_*.tex`-Module via `\environment`-Aufrufe.
  - `_layout_doc_*` — Seite/Flow/Fonts (z.B. `_layout_doc_fonts.tex`,
    `_layout_doc_flow.tex` mit Title/Subtitle-Placements).
  - `_layout_element_*` — per-Element-Layouts.

**Override-Modell:** ein gleichnamiges `_layout_*.tex`-Modul auf tieferer
Cascade-Ebene (z.B. `demoverlag/dhr/_assets/context/_layout_doc_fonts.tex`)
überschreibt das Root-Modul (last-wins via Asset-Shadowing). Kein
Spezial-Mechanismus — nur das generische Shadowing angewendet auf
ConTeXt-Umgebungsdateien.

**Image-Pfad:** ConTeXt bekommt das Bildverzeichnis via `--imagedir=<rel>`
(relativ zum `.build/pdf/`-Subprocess-cwd); die Umgebung resolved Refs via
`\getdocumentargument{imagedir}`.

**PDF-Nondeterminismus:** ConTeXt-PDFs sind *nicht* byte-deterministisch
(Timestamp + UUID in XMP/Info). Roh-Byte-Vergleich ist also kein valides
Build-Gate. (Siehe `docs/history.md`.)

### Lua-Filter-Kette (`md_to_xml`)

Reihenfolge ist kritisch — späterer Filter baut auf dem Output des
vorherigen auf:

```
author-notes-to-meta → abstract-to-meta → auto-classify-refs →
html-tables → pandoc-list-table → list-table → versify → classes-to-attr
```

**Warum genau diese Reihenfolge:** `versify` setzt `content-type` auf
Section-Elementen; `classes-to-attr` prependet Klassen als Attribute und
*muss danach* laufen, sonst überschreibt es die `content-type`-Werte. Die
`*-table`-Filter normalisieren Tabellen-Markup vor den strukturierenden
Filtern. `author-notes-to-meta`/`abstract-to-meta` ziehen Front-Matter aus
dem Body *bevor* die Struktur-Filter laufen.

### Validierung

Zwei Gates, beide über den File-Task-DAG an `xml_final` gekoppelt:

- **RNG** (`validate_xml_rng`): `jing.jar` gegen JATS-Publishing-1.2-RNG.
  Build bricht bei Grammatikfehlern.
- **Schematron** (`validate_xml_schematron`): `rules-journal.sch` pro
  Journal (article-type-Enum, DOI-Format). SchXslt2 auto-transpiliert die
  `.sch` zu `.xsl`; Wrapper-Aggregation bündelt mehrere Rules.

Weil `xml_final` das validierte Canonical-XML ist und alle Downstream-Stage
davon abhängen, gate-t Validierung automatisch *jeden* Downstream-Output.

---

## Querschnitt

- **Warnings-Framework:** `RCB.warn(msg)` sammelt non-fatale Warnungen;
  ein `at_exit`-Block gibt eine boxed Summary aus (auch bei Exception).
  Kanonischer Fall: MD-Override-Stale-Detection. (`core.md` → Warnings;
  generisch erweiterbar.)
- **Override/Stale:** zwei Override-Mechanismen, beide mit Stale-Signal:
  - *MD-Override:* hand-ediertes `source/<basename>.md` ersetzt die
    Auto-Konversion; `.compare`/`.stale`-Sidefiles signalisieren Zustand
    (DOCX neuer → `.stale` + `RCB.warn`). Lade-Zeit-Fork im
    `source_to_md`-File-Task.
  - *Image-Override:* `images-web/` als Override-Konvention für web-optimierte
    Bilder, analoger Stale-Check gegen `source/images/`.
- **`extract_metadata`:** interaktiver Task, der Metadaten (heute
  praktisch nur den Titel) via Pandoc aus dem Manuskript zieht und nach
  `metadata.yaml` merged (mit Diff + `[y/N]`, oder `--yes` /
  `CFG['extract_auto_apply']`). `_extract.protect:` schützt Felder vor
  Re-Extract. Nicht Teil von `build_all` (interaktiv).
- **Manifest als Single-Source:** alle Tasks entdecken ihre Inputs über
  `RCB.load_manifest` (sources, assets), nicht über eigene Filesystem-Walks.
  (`core.md` → Manifest.)
- **HTML-Output-Konvention:** Produktion-HTML bekommt `galley.css`
  serverseitig injiziert; Bilder liegen flach neben der HTML, nicht im
  `images/`-Subordner. (Test-HTML referenziert `galley.css` separat.)
- **Volume-PDF-Pipeline:** ein Volume-Level `rcb.rake` konsumiert die
  fertigen Artikel-XMLs und baut ein Volume-PDF mit eigenem ConTeXt-
  Template (parallele Pipeline auf derselben Cascade).

---

## Erweiterungs-Punkte

- **Neuer Cascade-Level:** Verzeichnis + optional `rcb.config.rb` /
  `rcb.rake` / `_assets/`. (`core.md` → Adding a New Cascade Level.)
- **Neuer Pipeline-Step:** `file`-Task mit Hash-Deklaration (`in`/`out`/
  `desc`) im publisher-`rcb.rake`, verdrahtet als Alias-Task. (`core.md`
  → Adding a New Pipeline Step.)
- **Task-Override auf tieferer Ebene:** gleichnamiger Task im tieferen
  `rcb.rake` ersetzt den Eltern-Task (Rake redefiniert bei Namensgleichheit,
  tiefere lädt später). Use-Cases: per-Journal-Branding, per-Volume-Skip,
  per-Artikel-Custom.
- **Neues Source-Format:** Register-Funktion + Eintrag im
  `SOURCE_FORMATS`-Hash im publisher-`rcb.rake`; `source_to_md` dispatcht
  über `CFG['source_format']`. Placeholder-Branches für `odt`/`tex`/`md`
  existieren als Kommentare (Roadmap Phase 17).
- **Standalone-Tasks:** Tasks, die nach `clean_build` einzeln laufen, müssen
  per-task ihr `mkdir` machen und volle Asset-Closure haben (z.B.
  `xml_clean` braucht `jats-dtd`, `validate_rng` braucht `jats-rng`) —
  File-Task-Helfer legen Verzeichnisse nur im `build_all`-Verbund an.