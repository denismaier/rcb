# RCB Roadmap — Forward-Only

**Stand:** 2026-08-28

Nur offene/geplante/Backlog-Items. Fertige Phasen, Entscheidungen und
Bau-Historie stehen in [`docs/history.md`](../history.md). Der Ist-Zustand
des Systems ist in [`docs/specs/core.md`](../specs/core.md) (Gem) und
[`pub/docs/dev/architecture.md`](../../pub/docs/dev/architecture.md)
(Pipeline-Komponenten) dokumentiert.

Status-Legende: 📝 pending · 🟡 partial · 💡 idea · ⏸️ deferred · 🎯 Zielarchitektur

---

## Offene Phasen

### Phase 2a: Cascade Task Override Demo 📝

**Priority:** Medium · **Effort:** ~2-4h

Rake erlaubt Task-Redefinition durch erneute Deklaration — tiefere
Cascade-Level können Eltern-Tasks überschalten (Core-Feature, in
`docs/specs/core.md` → Overriding a Task dokumentiert). Was fehlt: Demo-
Overrides auf Journal/Volume/Article-Ebene, die das Feature sichtbar machen
und als Vorlage dienen.

**Offen:**
- Demo: Journal-Override (`xml_to_html` für eigenes Branding), Volume-Skip
  (`xml_to_pdf` no-op), Article-Extend (pre/post-Actions).
- Optionaler `override_task`-Helper (`Rake::Task[name].clear`-Pattern).
- Test-Coverage (Override gewinnt, Skip, Extend).

### Phase 3: Pipeline Configuration via CFG 📝

**Priority:** Medium · **Effort:** 1-2d

Pipeline-Verhalten über CFG steuerbar machen.

**Geplant:** `CFG['skip_pdf']`, `CFG['skip_html']`, `CFG['enable_typo']`
(Feature-Flags); Tool-Konfiguration (`pandoc_from`, `context_mode`).
Conditional Task-Execution + dynamische Dependency-Chains.

### Phase 6: Testing & Validation 🟡

**Priority:** High · **Effort:** 2-3d (rest)

**Erledigt:** Unit-Tests (Core Logic, 2026-05-20, 16 runs/46 assertions);
manuelle Validation (Post-Merge-Sanity am necker-Artikel, 2026-08-28).

**Offen:**
- Integration-Tests (volle Pipeline auf Produktionsartikel).
- RCB-vs-Legacy-Makefile-Vergleich (Trigger: nach Phase 17).
- Feature-spezifische Tests (XSLT, Schematron, Lua-Filter).
- Begründung für Aufschub: Pipeline ändert sich noch (Pandoc-Update,
  Phase 17, ggf. Phase 22) — Tests jetzt zementieren würde ständige
  Test-Updates triggern. Siehe `docs/history.md` (2026-05-20).

### Phase 7: Asset Versioning 📝

**Priority:** Medium · **Effort:** ~4-6h

Reproduzierbare Builds + Traceability: welche Assets (Templates, XSLT,
Lua-Filter) wurden für einen veröffentlichten Artikel verwendet?

**Optionen:** Git-basiert (`git rev-parse`), Asset-Pin-File (`rcb.pin`),
Asset-Manifest im Build-Output. Empfehlung: Git-basiert.

### Phase 11: CI/CD Pipeline 📝

**Priority:** Medium · **Effort:** ~2-4h

Automatische Tests + Qualitätssicherung bei Push.

**Geplant:** CI-Workflow für `bundle exec rake test`; Test-Matrix (Ruby
3.0–3.3); Gem-Build-Validierung; optional RuboCop (aktuell deaktiviert wegen
Windows-Inkompatibilität).

### Phase 13: Watch Mode & Live Preview 💡

**Priority:** Low · **Effort:** ~2-3d

Komfort-Feature: `rcb watch` (Auto-Rebuild bei Dateiänderungen) + `rcb
preview` (lokaler HTTP-Server für HTML-Vorschau). Nutzt `listen`/`filewatcher`.

### Phase 17: Source-Format-Dispatcher 🟡

**Priority:** Medium · **Effort:** ~2h Scaffolding + N×~½d pro Format

**Erledigt:** Dispatcher als `SOURCE_FORMATS`-Hash (Format → Register-Funktion),
`docx` aktiv, Task-Rename `docx_to_md` → `source_to_md`.

**Offene Formate:**
- `odt` (Pandoc, vermutlich trivial).
- `tex` (Pandoc, evtl. mit Lua-Filter).
- `md` (Identitäts-Konversion; Override-Konzept entfällt — Source IST die MD).
- `xml` (möglicher Direct-Entry, würde MD-Pipeline umgehen; siehe Memory
  `project_pipeline_entry_model.md` — Single-Entry by design, Multi-Entry
  aufgeschoben).

### Phase 20b: `jats2html.xsl` modularisieren 📝

**Priority:** Medium · **Effort:** ~1-2d

Aktuell ~980 Zeilen, vermischt TOC/Front/Body/Back/Tabellen/Verse, plus
auskommentierte Code-Leichen.

**Target:** modularer Entry + Import-Module (`_toc`, `_frontmatter`, `_body`,
`_back`, `_tables`, `_figures`, `_verse`, `_rtl`); Code-Leichen entfernen.
(Phase 20a — `cleanup.xsl` als `p:xslt`-Steps auflösen — ist erledigt; siehe
`docs/history.md`.)

### Phase 20c: Calabash DTD-Default-Suppress ⏸️

**Priority:** Low (nicht blockierend)

DTD-Default-Expansion-Risk: jeder DTD-aware Loader, der die JATS-DTD via
Catalog auflöst, infliert Defaults (`position="float"`, `dtd-version`, …).
Suppress ist pro Tool zu setzen. **Morgana verifiziert**
(`mox:expand-default-attributes=false()` am `<p:load>`, 2026-06-25);
Saxon `-expand:off` aktiv. **Calabash**-Äquivalent offen (xproc-dev-Liste
2026-05-22, keine Antwort). Nicht blockierend — Pipeline läuft auf Morgana;
nur die `mox:`-Map ist Morgana-spezifisch und isoliert am Load-Step. Siehe
`docs/history.md` (2026-06-25).

### Phase 21a: Image specific-use ⏸️

**Priority:** Low (aufgeschoben)

JATS `<graphic specific-use="print"/"online">` für unterschiedliche
Auflösungen. **Aufgeschoben (2026-05-19):** kein konkreter Print-Use-Case.
PDFs werden online konsumiert und nutzen dieselben Web-Bilder wie HTML;
Artikel gehen nicht zum Verlag. Trigger: Druckprodukt/Repro-Bundle, das
hires-Bilder braucht.

### Phase 22: Declarative Steps DSL 🎯

**Priority:** Medium-High (richtungsentscheidend) · **Effort:** ~1-2W

Zielarchitektur: RCB von imperativen Rake-Tasks zu deklarativer
Step-basierter DSL. Steps als reine Daten (`from`/`to`-Ports, Tool,
Parameter), Pipeline als Komposition, DAG ergibt sich automatisch
(XProc-inspiriert).

**Sub-Phasen (Entwurf):**
- 22a Step-Registry — generische Anmeldungs-API statt ad-hoc
  `SOURCE_FORMATS`-Hash.
- 22b DAG-Resolver — automatische Verkettung statt manueller
  Hash-Key-Verdrahtung (`md_to_xml[:in] = md_final[:out]`).
- 22c Composite Steps — Pipeline ist selbst ein Step
  (`build_publish` = Composite).
- 22d Cascade-Override auf Step-Ebene — Ablösung des
  `Rake::Task[name].clear`-Patterns.

**Grundlage gelegt:** Hash-basierte Step-Deklarationen (Phase 15),
Source-Format-Dispatcher als Registry-Prototyp (Phase 17).

---

## Nebeneinträge (keine eigene Phase)

### Rezensionen — besprochenes Werk aus dem Titel raus

Status quo: bibliografische Angabe des besprochenen Werks grob im
`article-title` verstaut. Sauberer JATS-Weg: `<product>` (mit
bibliografischen Feldern) oder `<related-object>` in article-meta, plus
Metadata-Schema plus Renderer-Handling. Betrifft `book-review` und
`review-essay`. **Größerer Task** (Metadata-Schema + Template-Block + beide
Renderer). Eingriffsort ist die Renderer (`jats2html.xsl` + `jats.tex`),
nicht das Pandoc-Template. Siehe Memory `project_template_followups.md`.

### jats.tex-Modularisierung ⏸️

`jats.tex` (XML→TeX-Mapping, ~1426 Zeilen) bleibt Monolith. Per-Element-
Override braucht evtl. feinere Granularität als Modul-Ersetzen —
ConTeXt-XML-Override-System (`\xmlsetsetup`/`\startxmlsetups`) erst klären.
Zurückgestellt (2026-08-24). Siehe `docs/history.md`.

### CSL + tiefere Refs-Strukturierung 💡

CSL-Anbindung (Zitationsstil-Steuerung) und tiefere Strukturierung der
Referenzen (typisierte `<mixed-citation>` mit Element-Awareness statt
Plain-Text). **Bewusst nicht gewollt** (2026-08-28): aktuelles Setup reicht,
kein Blocker, eventuell später. Siehe `docs/history.md` (Phase 25).

### Anchor-Default — Rest-Display-Elements 📝

`_anchor-default.xsl` schreibt `position="anchor"` nur auf `boxed-text`
(Prototyp, 2026-07-03). Die übrigen display-atts-Elemente (`fig`,
`fig-group`, `table-wrap`, `table-wrap-group`, `chem-struct-wrap`,
`supplementary-material`, `graphic`, `media`, `code`, `preformat`, `array`,
`chem-struct`) bleiben unangetastet, bis ihre downstream-Implikationen
geprüft sind. `@orientation` (Default `portrait`) wird nicht
mit-normalisiert.

### MD-Body-Filter (Byline automatisch raus) 💡

Backlog aus `pub/docs/user/article-workflow.md` Schritt 2: es gibt (noch)
keinen Body-Filter, der Byline/Autor/Affiliation/Email automatisch aus dem
Body entfernt — der Editor muss sie im Word löschen, sonst doppelt im
Front-Matter. Filter würde das automatisieren.

---

## Siehe auch

- [`docs/history.md`](../history.md) — fertige Phasen, Entscheidungen, Bau-Historie
- [`docs/specs/core.md`](../specs/core.md) — RCB-Gem-Spec
- [`pub/docs/dev/architecture.md`](../../pub/docs/dev/architecture.md) — Pipeline-Komponenten
- [`pub/README.md`](../../pub/README.md) — Pipeline-Referenz