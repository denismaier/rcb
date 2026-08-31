# History — Entscheidungen & was gemacht wurde

Chronologische Bau-Historie des RCB-Projekts: welche Entscheidungen
getroffen wurden, warum, und welche Änderungen daraus folgten. Breiter als
reine ADRs — auch "was wurde gebaut". **Kein Plan** (Forward steht in
`docs/plans/roadmap.md`); **keine Reference** (Ist-Zustand steht in
`docs/specs/core.md` + `pub/docs/dev/architecture.md`).

Format je Eintrag: **Decision** / **Rationale** / **Changes**. Ältere
Einträge sind auf das Entscheidungs­relevante gestrafft.

---

## 2026-03 — Fundament

### 2026-03-09: Metadata vs. Konfiguration trennen
**Decision:** Info-Tasks lesen aus `metadata.yaml`, nicht aus CFG.
**Rationale:** Single Source of Truth, Redundanz weg.
**Changes:** CFG = Build-Config (paths, tools, flags); `metadata.yaml` =
Content-Metadata (Titel, ISSN, Autoren). Redundante CFG-Werte entfernt
(`journal_name`, `journal_issn`, `volume_number`, `article_title`).

### 2026-03-09: Architektur-Refactor (BUILD_DIR/OUTPUT_DIR)
**Decision:** `BUILD_DIR`/`OUTPUT_DIR` als Konstanten.
**Rationale:** DRY, einheitliche Pfade.
**Changes:** Alle Tasks nutzen `BUILD_DIR/"..."` bzw. `OUTPUT_DIR/"..."`;
redundante `mkpath`-Calls entfernt; `init`-Meta-Task.

### 2026-03-09: rcb-dev Wrapper
**Decision:** Bash-Wrapper in `~/.local/dev-bin` statt `gem install`.
**Rationale:** Dev-Modus, Änderungen sofort aktiv.

### 2026-03-23: Manifest als Single Source of Truth
**Decision:** Pre-Task-Phase generiert ein Manifest (Cascade-Struktur,
resolved CFG, Files, Metadata) nach `.build/manifest.yaml`.
**Rationale:** Tasks lesen aus dem Manifest statt selbst das Filesystem zu
walken — eindeutige Quelle, inspectable, DRY.
**Changes:** `rcb/lib/rcb.rb` Manifest-Generierung; `scan_*`-Erweiterungen.

### 2026-03-24: Pipeline auf file tasks umstellen
**Decision:** Imperative `task`-Blöcke → Rake-`file`-Tasks mit
Hash-basierten Step-Deklarationen.
**Rationale:** Inkrementalität (mtime), expliziter Daten-Flow-DAG,
Vorbereitung für declarative-Steps-DSL.
**Changes:** `rcb.rake` restrukturiert; assets/source/images/metadata
schrittweise migriert (bis 2026-04-24).

---

## 2026-04 — Config-Phase, Override, Filter-Anbindung

### 2026-04-24: Two-Phase-Loading via `rcb.config.rb`
**Decision:** CFG-Setup aus `rcb.rake` herauslösen in eigene
`rcb.config.rb` pro Cascade-Ebene; rcb lädt **alle** Configs zuerst,
**dann** alle Rakefiles.
**Rationale:** Pipeline-Tasks in `rcb.rake` lasen CFG-Werte zur Load-Zeit,
die erst durch später ladende Article-Rakefiles gesetzt wurden →
`nil`-Interpolation in file-task-Targets.
**Changes:** Two-Phase-Loader in `rcb.rb`; `rcb.config.rb` pro Ebene;
CFG-Defaults aus `rcb.rake` ausgelagert.

### 2026-04-24: Source-Format-Dispatcher als Lookup-Tabelle
**Decision:** `SOURCE_FORMATS`-Hash (Format → Register-Funktion) statt
`case`-when.
**Rationale:** Trennt Dispatch von Implementation. Neues Format =
Hash-Eintrag + Register-Funktion, kein Eingriff in den Dispatcher.
**Changes:** `source_to_md`-Block; Task-Rename `docx_to_md` →
`source_to_md` (breaking).

### 2026-04-24: Override-Fix via Lade-Zeit-Fork
**Decision:** Override-Logik in einen alternativen file task ziehen, nicht
im Alias-Task.
**Rationale:** Alias-Task stand in keiner Dependency-Chain; Lade-Zeit-Fork
hält Rake's file-task-DAG sauber und nutzt bestehende Inkrementalität.
**Changes:** `source_to_md`-Block; `.compare`/`.stale`-Sidefiles statt
reiner Log-Warnung; Stale-Check gegen Manifest-Origin-mtimes.

### 2026-04-24: Warnings statt Stoppen
**Decision:** Non-fatale Warnungen am Prozessende bündeln (`RCB.warn` +
`at_exit`-Summary), nicht interaktiv stoppen.
**Rationale:** CI/Automation bricht beim Prompten; Volume-Builds mit N
Artikeln würden N-mal fragen; paternalistisch für Autoren, die bewusst
Override setzen. `--strict` auf Backlog.
**Changes:** `RCB::WARNINGS` + `RCB.warn()` + `at_exit` in `rcb.rb`.

### 2026-04-24: Kein `--extract-media` in docx→md
**Decision:** Pandoc-Flag entfernen.
**Rationale:** Degradiert Lua-Filter-generierte Bildreferenzen zu
`.placeholder`. Embedded-images eh nicht supported — Autor liefert Bilder
via `source/images/` + image-markers.

### 2026-04-28: Lua-Filter-Audit + Pipeline-Anbindung
**Decision:** RCB band im `md_to_xml`-Step **keinen** der acht
Production-Lua-Filter ein — das war eine Feature-Lücke, kein Aufräumen.
Alle acht Production-Filter werden angebunden; `headings-refs-to-meta`
wird durch `auto-classify-refs` ersetzt (Refactor, kein Patch);
`ignore-content-abstract` gelöscht (bug-laden, Duplikat von
`abstract-to-meta`).
**Rationale:** Single canonical path über `cleanup.xsl` — kein
Konkurrenzverhältnis zwischen Lua-Extraktion und XSLT-Transformation.
Bug-laden Code (`print()`-Debug, toter Sprach-Fallback) fliegt raus;
`auto-classify-refs` ~30 Zeilen statt ~85.
**Changes:** Filterkette `md_to_xml` =
`author-notes-to-meta → abstract-to-meta → auto-classify-refs →
html-tables → pandoc-list-table → list-table → versify → classes-to-attr`.
**Reihenfolge kritisch:** `versify` setzt `content-type`;
`classes-to-attr` prependet und muss danach laufen.

**Filter-Inventar (12):**

| Filter | Decision |
|--------|----------|
| author-notes-to-meta, abstract-to-meta | behalten + eingebunden |
| auto-classify-refs (vormals headings-refs-to-meta) | refactored (nur Klassifikation, kein Extract) |
| html-tables, pandoc-list-table, list-table, versify, classes-to-attr | behalten + eingebunden |
| image-markers | behalten (RCB-only, `source_to_md`) |
| ignore-content-abstract | gelöscht |
| pandoc-parallel-tables | offen (kein Production-Einsatz) |
| pprint.lua | behalten (Debug-Library, kein Pipeline-Filter) |

### 2026-04-28: ConTeXt cwd-Wechsel via Subprozess-Option
**Decision:** `Open3.capture3`'s `chdir:`-Argument statt `Dir.chdir` im
Ruby-Prozess.
**Rationale:** Wechselt nur das cwd des ConTeXt-Subprozesses, der Parent
bleibt unberührt — löst das Thread-Safety-Problem mit minimaler Diff,
bestehende relative Pfade bleiben gültig (keine Windows-Pfad-Quirks).

---

## 2026-05 — Validierung, Typografie, Schematron

### 2026-05-19: XML-Validierung via RNG (jing) statt DTD (xmllint)
**Decision:** Phase 18a mit `jing` + JATS-RNG, nicht `xmllint --valid` +
DTD. DOCTYPE wird in einer Temp-Kopie für die Validation gestrippt;
Original bleibt unverändert.
**Rationale:** RNG expressiver als DTD, entkoppelt vom DOCTYPE-Lookup.
`jing` schon installiert, `xmllint` nicht. Jing will den DTD-Pfad auflösen
→ DOCTYPE-Strip in Temp-Kopie als kleinstmögliche Lösung.
**Changes:** `validate_xml_rng`-Step; `CFG['jing_jar']`; `jats-rng/`
committet; DTD-Bundle aufgeräumt.

### 2026-05-19: validate_xml_rng vor xml_final (statt nach xml_publish)
**Decision:** Validierung wandert zwischen `xml_clean` und `xml_final`;
`xml_final[:in]` → `validate_xml_rng[:out]`.
**Rationale:** Konvention `*_final` = Endpunkt einer Teil-Pipeline. Validate
hinter `xml_publish` brach das auf und nötigte explizite Alias-Deps.
Validate-before-final ist fail-fast. RNG akzeptiert ConTeXt-PIs.
**Changes:** `validate_xml_rng` verschoben; `xml_final[:in]` +
`xml_to_output[:in]` umgehängt; 4 Alias-Task-Arrays befreit.

### 2026-05-19: Typografie von Python nach XSLT migrationieren
**Decision:** `md_typo` (Python/pyenv) → `xml_typo` (XSLT/Saxon).
**Rationale:** Python-Dependency vermeiden; Typografie ist
XML-Transformation, passt in die XSLT-Pipeline; läuft nach Validierung,
da nur Textinhalte geändert werden.
**Changes:** `md_typo` entfernt; `xml_typo` zwischen
`validate_xml_schematron` und `xml_final`; `_typography.xsl` erstellt;
Python-Skript gelöscht. Bug-Fixes: Function-Namespace, `text()`-Priority,
korrekte Unicode-Spaces (NNBSP U+202F / NBSP U+00A0).

### 2026-05-20: Keine Re-Validation nach xml_typo
**Decision:** `xml_typo`-Output wird nicht erneut validiert.
**Rationale:** Typo-XSLT modifiziert nur `text()`-Nodes (Identity-Template
+ Override); Element-Struktur/Attribute/DOCTYPE unangetastet.
**Guard:** Wer Typo-Regeln auf Attribute/Element-Generierung/strukturelle
Transforms erweitert, MUSS einen zweiten Validation-Step einbauen.

### 2026-05-20: Typografie-Scope feiner gefasst
**Decision:** `text()`-Template excludet nicht mehr `ancestor::front`
ganz, sondern spezifische Elemente: Namen-Container (`name`,
`string-name`), Identifier (`article-id`, `pub-id`, `issn`, …), URLs
(`email`, `uri`, `ext-link`) + Code-Elemente.
**Rationale:** Pauschaler `<front>`-Ausschluss schloss auch `<abstract>`,
`<article-title>`, `<license-p>` von Typografie aus, obwohl das
Python-Original diese behandelte.

### 2026-05-20: Schematron-Regeln auf tiefstmögliche Cascade-Ebene
**Decision:** Schematron-Regeln gehören aufs Journal-Level, nicht aufs
Publisher-Level. Multi-Validation-Mechanismus (alle `.sch` additiv) erst
gebaut, wenn ein zweites Journal eigene Regeln braucht.
**Changes:** `jndf-basis.sch` → `<journal>/_assets/schematron/`.

### 2026-05-20: Schematron Multi-Validation via generated wrapper
**Decision:** `validate_xml_schematron` aggregiert alle `.sch` via
generiertem `_combined.sch`-Wrapper (ISO-2025-`<sch:extends href="…"/>`);
SchXslt2 1.10+ resolved extends bei der Transpile. Eine Invocation, ein
Report.
**Rationale:** Statt n×Saxon-Aufrufe + n SVRLs + Ruby-Aggregation nativ
in Schematron.
**Convention:** `.sch`-Files heißen `rules-<level>.sch`; `_*.sch` =
Prefix-Reserve für generated Files.

### 2026-05-19: JATS-DTD bleibt im Repo
**Decision:** "JATS-DTD auslagern" (Phase 23) zum Cleanup heruntergestuft —
DTD-Bundle bleibt unter `_assets/jats-dtd/`.
**Rationale:** Roadmap-Schätzung 74 MB war falsch — tatsächlich 1.9 MB.
Auslager-Mechanismus lohnt sich nicht. DTD wird von Saxons Katalog für
Entity-Auflösung im `xml_clean`-Step gebraucht.

### 2026-05-19: xml_to_zip als Reproduzierbarkeits-Bundle
**Decision:** Phase 19 als self-contained Bundle für OJS-XML-Upload, nicht
als OJS-Import-Format. Inhalt: XML + Web-Bilder flach + Originale in
`original-images/`.
**Rationale:** Use Case "XML allein ist nutzlos, Empfänger kommt nicht an
Bilder". PDF/HTML gehören nicht rein. Tool: Info-ZIP CLI (kein Gem-Dep).

### 2026-05-19: Phase 21a (Image specific-use) aufgeschoben
**Decision:** JATS `specific-use="print"/"online"`-Bildvarianten nicht
bauen bis konkreter Print-Use-Case.
**Rationale:** PDFs werden in der Praxis online konsumiert; niemand druckt
für den Verlag. Zwei Rendering-Ziele ohne konsumiertes zweites =
Over-Engineering. Trigger: Druckprodukt/Repro-Bundle.

### 2026-05-20: Image-Pipeline nimmt flat layout an
**Decision:** `convert_images`/`images_to_output`/`xml_to_zip` nutzen
`File.basename` — kein Subdir-Support.
**Rationale:** Bilder flach unter `source/images/<datei>`. Subdir-Support =
Komplexität ohne Use-Case (YAGNI).
**Guard:** Bei künftigen Subdirs: Target-Naming auf vollen `rel_path` +
Kollisions-Detection.

### 2026-05-20: aff/@id-Strip mit präzisem Predicate-Match
**Decision:** `aff`-Strip von `match="aff"` auf
`match="aff[@id='aff-' or @id='']"` verengt.
**Rationale:** Pauschal-Strip war zu aggressiv — würde künftige Template-
Erweiterungen mit YAML-`id`-Feldern still entfernen und xref-Verlinkung
kaputt machen. Legitime IDs bleiben byte-identisch.

### 2026-05-20: Keine Pre-Flight-Checks für Tool-Pfade
**Decision:** Tool-Verfügbarkeit wird nicht vor Task-Start geprüft.
Fehlt ein Tool, schlägt der Task mit der Tool-eigenen Fehlermeldung fehl
(let-it-crash).
**Rationale:** Existing Diagnose ist ausreichend; Aufwand/Nutzen für den
~1×/Jahr-Fall "mehrere Tools fehlen gleichzeitig" spricht für
let-it-crash.

### 2026-05-20: Phase 6 in drei Etappen
**Decision:** (1) Unit-Tests für rcb-Kern ✅, (2) manuelle Validation mit
echtem Artikel, (3) Integration-Tests erst nach (2).
**Rationale:** Pipeline ändert sich noch (Pandoc-Update, Phase 17, ggf.
DSL) — Integration-Tests jetzt zementieren würde Test-Updates triggern.
Core-Unit-Tests sind stabil (Cascade-Modell nicht in Bewegung).
**Trigger für (3):** Nach Pandoc-Update + Phase 17.

---

## 2026-06–07 — XProc-Migration (Phase 20a)

### 2026-06-25: Phase 20 weiter mit Morgana, Calabash zurückgestellt
**Decision:** XProc-Migration baut vorerst ausschließlich auf Morgana; die
offene Calabash-Frage blockiert nicht.
**Rationale:** Morgana-Suppress für DTD-Default-Expansion verifiziert
(`mox:expand-default-attributes=false()` am `<p:load>`). Für Calabash fehlt
das Äquivalent. Portabilitäts-Kosten gering: nur die `mox:`-Map ist
Morgana-spezifisch und isoliert am Load-Step.

### 2026-06-25: 20a-Architektur korrigiert (Auflösung statt Entry)
**Decision:** 20a-Ziel ist **nicht** ein `cleanup.xsl`-Entry mit
`xsl:import`, sondern die **Auflösung** von `cleanup.xsl`: jedes Modul
wird ein eigener `p:xslt`-Step; `cleanup.xsl` schrumpft pro Extraktion und
wird am Ende gelöscht.
**Rationale:** `_sections.xsl` war bereits eigener Step — eine
Include-in-Entry-Vision würde diesen Präzedenz brechen. Serialisierung
wandert nach `p:output serialization=…` (entkoppelt von Step-Reihenfolge).
**Anchor-Default aufgeschoben:** damit 20a byte-identisch bleibt und die
Semantik-Änderung separat verifizierbar ist.

### 2026-06-26: Migrations-Gate auf semantische Parität umdefiniert
**Decision:** "byte-identisch zum heutigen xml_clean-Output" wird
**fallengelassen**. Gate = **semantische Korrektheit**.
**Rationale:** Die zwei verbleibenden Differenzen sind keine
Semantik-Differenzen: (a) Serialisierung — Morgana `p:output` formatiert
DOCTYPE/Attribute anders als Saxon `xsl:output` (einzeilig vs.
mehrzeilig), InfoSatz identisch; (b) `generate-id()` pro-Transformation
nicht portabel (`d1e`- vs `d2e`-Prefix), Artefakt. Sandbox-gegen-Sandbox
`fc /b` bleibt als Regression-Test intakt.

### 2026-06-26: 20a abgeschlossen — Module extrahiert, `cleanup.xsl` gelöscht
**Decision:** Restliche `cleanup.xsl`-Blöcke als eigene `p:xslt`-Module
(`_back-moves`/`_sections`/`_figures`/`_tables`/`_blocks`); `cleanup.xsl`
gelöscht. Drei kleine Strips als **XProc-Primitive** (`p:unwrap`/
`p:delete`/`p:viewport`), nicht als XSLT.
**Rationale:** Große Content-Transforms bleiben XSLT-Steps; kleine Strips
zeigen XProc-native Primitive. PI/identity/article-Templates fallen via
`xsl:mode on-no-match="shallow-copy"` der Module. Bewiesen durch Case
`00-pi-survival`.
**Label-in-moved-content-Fix:** Reihenfolge in `cleanup.xpl` geflippt —
`_back-moves.xsl` läuft **vor** `_sections.xsl` (ref-list/app-secs am
Body-Ende werden vor dem Nummerieren entfernt).
**Verifiziert:** `tests.bat` 14/0.

### 2026-07-03: Anchor-Default für `boxed-text` (Prototyp)
**Decision:** Aufgeschobene Anchor-Default-Normalisierung als eigener
`_anchor-default.xsl`-Step — schreibt `position="anchor"` auf
`boxed-text` ohne `@position` (idempotent). Läuft nach `_blocks`, vor den
Strips. Scope nur `boxed-text` (Prototyp).
**Rationale:** JATS-Default für `@position` ist `float`; Suppress
verhindert das Inflaten → "kein `@position`" bedeutet implizit *anchored*.
Der Step macht es explizit. Nach `_blocks`/`_tables`, weil Wrapper, die dort
gestrippt/umgewandelt werden, fälschlich ein `anchor` bekämen.
**Verifiziert:** `tests.bat` 15/0.

### 2026-07-08: XProc-Cleanup-Pipeline nach Production portiert
**Decision:** In der Sandbox (`experiments/xproc-cleanup/`) entwickelte
Pipeline wird nach Production portiert: `cleanup.xpl` + sechs `.xsl`-Module
per `git mv` nach `_assets/xproc/`; `xml_clean`-Step auf Morgana/`cleanup.xpl`
umgewired; monolithische `cleanup.xsl` gelöscht. Sandbox → reine
Test-Harness (`tests.bat` referenziert Production-`.xpl`).

### 2026-07-08: `nonumheadings` verdrahtet — beide Seiten jointly aus einem CFG-Flag
**Decision:** `nonumheadings` (Section-Heading-Nummerierung abschalten) von
"deklariert aber ungesetzt" auf "verdrahtet" gehoben. **Ein**
`CFG['nonumheadings']` (Default `false`) treibt XSLT *und* ConTeXt jointly.
**Rationale:** Legacy-Makefile gab die Variable an Saxon; ConTeXt-Seite
wurde dort manuell über separate `context-mode`-Variable gefahren
("doppelt angeben, nicht elegant"). RCB ersetzt die Doppel-Spec durch ein
Flag. Touch-Points: XSLT-Seite (`_sections.xsl` überspringen → keine
`<label>`-Nummern); ConTeXt-Seite (`--mode=…,nonumheadings` aktiviert
`\startmode[nonumheadings]`).
**Nuance:** Figure/Table-Labels unangetastet (nur Section-Numbering).
**Caveat:** Flag-Wechsel triggert keinen Rake-Rebuild (Cmd-String kein
file-task-Dep) → Source `touch` oder `clean_build`.

---

## 2026-08 — ConTeXt-Modularisierung, Standalone-Fixes, Pandoc-Update

### 2026-08-24: ConTeXt `layout.tex` in 21 Module modularisiert (Phase 5)
**Decision:** `layout.tex` (~873 Zeilen) → 21 `\environment`-Module;
Driver wird zum dünnen Orchester (21 bare `\environment[_<modul>]`-Aufrufe).
Namens-Schema: `_layout_doc_*` (12 generelle Settings) /
`_layout_element_*` (9 Content-Elemente), namespace `layout`. Override =
reines **Ersetzen** auf Modul-Granularität (gleichnamiges `_modul.tex` auf
tieferer Ebene gewinnt per `scan_assets` last-wins).
**Rationale:** Pro-Journal/pro-Artikel-Anpassung war bisher nur als
ganzer-Datei-Override möglich (journal_2 spiegelte den kompletten
Monolithen). Modul-Granularität: ein Journal überschreibt nur z.B.
`_layout_doc_fonts`, ohne den Rest zu duplizieren. ConTeXt löst
`\environment` relativ zum **cwd** auf (empirisch 2026-07-10) — Driver
deklariert Pfad per `\usepath`. Stilles No-Op bei nicht existierender Datei
macht Driver↔Datei-Cross-Check zur verlässlichen Prüfung.
**Naming-Entscheidungen:** `_layout_doc_*`/`_layout_element_*` über
3-Tier-`_settings_*` und `_misc` (Junk-Drawer). `_layout_doc_legacy` als
status-ge scopetes dormant-Referenz-Modul. Footer-Info + Pagenumbering
zusammengeführt in `_layout_doc_page_header_footer`. flow + modes in einem
Modul (`_layout_doc_flow`). `doiafterauthor` entfernt (repo-weit nie
referenziert).
**journal_2-Override-Demo:** 876-Zeilen-Monolith-Override → einzelnes
`_layout_doc_paragraph.tex`-Modul (beweist Modul-Override end-to-end).
**jats.tex zurückgestellt:** Per-Element-Override braucht evtl. feinere
Granularität (ConTeXt-XML-Override-System erst klären).
**Verification:** Cross-Check 21/21, `xml_to_pdf_test` grün, content-neutral.
Gate = "build green + inhaltlich identisch" (ConTeXt-PDF nicht
byte-deterministisch — Timestamp+UUID in XMP/Info).

### 2026-08-24: Standalone Pipeline-Tasks self-sufficient nach `clean_build`
**Decision:** Drei Gaps, die standalone Task-Aufrufe nach `clean_build`
brachen und von `build_all` maskiert wurden, werden geschlossen — ohne
`:setup_build`/`:prepare_assets` als Krücke. Jeder Pipeline-File-Task wird
selbstgenügend.
**Gaps & Fixes:**
1. **mkdir-Gap:** ~19 Pipeline-File-Tasks legten ihr Output-Verzeichnis
   nicht selbst an → `mkdir_p(File.dirname(t.name))` am Block-Anfang.
2. **Asset-Staging-Gap:** Catalog/RNG-resolvierende Tasks dependierten nur
   auf ihrem primären File, nicht dem Asset-Baum (`xml_clean` braucht
   ganzen `jats-dtd/`, `validate_xml_rng` ganzen `jats-rng/`) →
   Load-Zeit Asset-Closure-Deps.
3. **Schematron-Skip-Gap:** `validate_xml_schematron` raise-te hart bei
   leerem `.sch`-Set (Journal ohne eigene Regeln ist legitim) → Passthrough
   + `RCB.warn`.
**Diagnose-Heuristik:** standalone nach `clean_build` + Task liefert Success
aber keinen Output → fehlende Asset-Closure.

### 2026-08-28: Pandoc-Update auf master gemerged (3.1.2 → 3.10.2)
**Decision:** Pandoc 3.1.2→3.10.2, Binary-Pinning via `CFG['pandoc_cmd']`,
JATS-Template-Rebase auf den 3.10.2-baked-in-Partial + 3 JNDF-Mods
re-applied. Merge 213e8f2.
**Dep-Wiring verifiziert:** `md_to_xml` deklariert Template + Lua-Filter +
Metadata als file-task-Deps → Template-Rebase triggert XML-Rebuild;
inkrementelle Builds lügen nicht.
**Validation (Clean-Rebuild am Produktionsartikel jndf-2026-3-necker):**
Komplette Pipeline grün; ConTeXt-Log sauber; User-Augenschein HTML/PDF "sieht
gut aus".
**Scope:** Post-Merge-Sanity, NICHT der RCB-vs-Legacy-Makefile-Comparison
(bleibt offen, Trigger s. Phase 6).

### 2026-08-28: Image-Manual-Override (`images-web/`)
**Decision:** Analog zum MD-Override bekommt die Image-Pipeline einen
Override: eine vorbereitete Web-Bild-Version in `source/images-web/`
überspringt die automatische ImageMagick-Konversion für diese Datei.
**Convention:** `source/images/` = Originale (auto-konvertiert);
`source/images-web/` = vorbereitete Web-Bilder (Override, 1:1 kopiert).
`images-web` mit Bindestrich matcht das Build-Verzeichnis `.build/images-web/`.
**Matching:** pro Bild wird das Target berechnet (TIFF→JPG-Rename, sonst
Basename); existiert `images-web/<target>` im Manifest → Copy-Task statt
Convert-Task.
**Stale-Check:** analog MD-Override — Original neuer als Override →
`RCB.warn` mit STALE OVERRIDE. Kein Compare-File (Bilder nicht
text-comparbar).
**Manifest-Integration:** `scan_source` walkt `source/` rekursiv, also
erscheint `source/images-web/photo.jpg` natürlich als Key `images-web/photo.jpg`.

### 2026-08-28: Plain-Text-Referenzen für Crossref/OJS (`xml_to_refs`)
**Decision:** Neuer Pipeline-Step `xml_to_refs` + `refs_to_output`
extrahiert pro Artikel die `<ref>`-Liste als reinen Text (eine Referenz pro
Zeile) für den Crossref-Deposit/OJS-Upload. Output:
`output/refs/<basename>-references.txt`, in `build_publish` verdrahtet.
**XSLT `jats2refs.xsl`** (`method="text"`): `//ref-list/ref[mixed-citation]`
→ `normalize-space(mixed-citation)`. `<italic>` fällt über text-Methode weg.
Keine Ref-Nummer, kein Sektionstitel. Mehrere ref-lists flach in
Dokumentreihenfolge. Siglen inkludiert (label-frei, da `mixed-citation`
selektiert wird, nicht das `ref`-Ganze). Leerer Artikel → 0-Byte-Datei.
**Caveat (ext-link):** `normalize-space()` nimmt den Link-Text, nicht
`xlink:href` — in den Daten ist der Link-Text die URL selbst.

### 2026-08-28: Bibliography Handling Review abgeschlossen (Phase 25)
**Decision:** Refs-Handling nach Pandoc-Update + Phase 25 angeschaut.
Layering-Kette `auto-classify-refs.lua` → `classes-to-attr.lua` →
`_back-moves.xsl` ist **bewusst gewachsen** — löst das Mehrebenen-Problem
(Quellen + Sekundärliteratur + Siglen), das der ältere direkte
Überschrift→`ref-list`-Filter nicht abdeckte. **Keine Vereinfachung möglich
ohne Rücknahme in den Broken-Zustand.** CSL bewusst nicht gewollt ("aktuelles
Setup reicht, kein CSL im Moment, eventuell später") — kein Blocker.
**Dead-Code-Template entfernt:** `<xsl:template match="ref-list">` in
`_back-moves.xsl` — Überbleibsel vom gedroppten `headings-refs-to-meta`-Filter,
wrappte ein präexistentes `<ref-list>`, das in der aktuellen Pipeline nie als
Input existiert. Entfernt, byte-identischer Output.

### 2026-08-28: Subtitle-Rendering in HTML + PDF (Template-Followup 1)
**Decision:** Erster Folge-Task nach Pandoc-Template-Rebase: `<subtitle>`
aus JATS `title-group` wird in **beiden** Renderern sichtbar (vorher nur
`article-title` gelesen, `<subtitle>` unsichtbar).
**Renderer-Änderungen (jeweils nach `article-title`):**
- **HTML** (`jats2html.xsl`): `<p class="subtitle">` bei vorhandenem
  `title-group/subtitle` (`.node()`-apply, Inline-Markup erhalten).
- **PDF** (`jats.tex` + `_layout_doc_flow.tex`): neues
  `\xmlsetsetup …subtitle` (flush-only) + `subtitle=`-Documentvariable +
  `\startsetups placesubtitle` (mode-aware `\tfa`/`\tf`), verdrahtet im
  `\setuphead[title] after=`. Idempotent via `\doifnot{subtitle}{}`.
**Demo-Nutzung:** `dhr-2026-001-musterfrau/metadata.yaml` mit `subtitle:`.
**Offen (Folgetask 2):** Rezensionen — besprochenes Werk als
`<product>`/`<related-object>`, Angabe aus dem Titel raus.

### 2026-08-31: Alle externen Tools pfad-konfigurierbar (CFG `*_cmd`)
**Decision:** Alle fünf verbleibenden hartcodierten Tool-Aufrufe in
`pub/rcb.rake` auf CFG-Keys umstellen: `morgana`, `context`, `zip`,
`java`, `transform` (Saxon-CLI) → `CFG['xproc_cmd']`/
`CFG['context_cmd']`/`CFG['zip_cmd']`/`CFG['java_cmd']`/
`CFG['xslt_cmd']`, analog zum bestehenden `pandoc_cmd`-Muster mit
bare Default + ENV-Fallback (`RCB_XPROC_CMD` usw.). Der XProc-Runner
(Default: Morgana) und der XSLT-Runner (Default: Saxons `transform`)
sind **funktionsbenannt**, die übrigen toolbenannt: der Key benennt,
was der Schritt tut (XProc/XSLT anwenden) — passt auch für einen
künftigen anderen Prozessor (Calabash, Phase 20c). Caveat: die
Aufruf-Flags in `rcb.rake` bleiben tool-spezifisch (Morganas
`-catalogs=`/`-option:`, Saxons `-xsl:`/`-catalog:`) — der Name ist
Intent, keine Portabilitätsgarantie.
**Rationale:** Clone-freundlichkeit: kein Tool muss auf PATH liegen —
pinned Versionen (z. B. Pandoc 3.10.2) oder absolute Pfade sind pro
Maschine über `rcb.config.local.rb` bzw. ENV setzbar, ohne rcb.rake zu
editieren. Vorher waren nur Pandoc/ImageMagick + JAR/XSL-Pfade
konfigurierbar; die fünf restlichen waren bare Literale (gleiche
PATH-Risiken). Damit ist jetzt **jedes** externe Tool einheitlich
konfigurierbar. `zip` rückte dabei zusätzlich ins idiomatische
Task-Hash-Muster (`xml_to_zip[:tool]` statt Inline-Literal); die beiden
`java`-Literale in `validate_xml_schematron` (Transpile + Validation)
waren zuvor am Hash-Key vorbei direkt in den cmd-Arrays.
**Changes:** `pub/rcb.config.rb` (+5 Keys),
`pub/rcb.config.local.example.rb` + `docs/setup.md` ergänzt
(ENV-Liste, Tool-Tabelle, Beispiele). Verifikation: kaltes
`build_all` auf dem Demo-Artikel (`jds-2026-001-mustermann`)
vollständig grün (xproc/java/xslt/context);
`xml_to_zip` separat mit temporärem Testbild verifiziert (Demo-Artikel
hat keine Bilder — Task ist load-zeit-gated), danach Rückbau.

### 2026-08-29: Catalog-DOCTYPE entfernt (xml_typo/Saxon-Catalog-Bug)
**Decision:** DOCTYPE aus der Catalog-Datei
`pub/_assets/jats-dtd/catalog-jats-v1-2-no-base.xml` entfernen.
**Rationale:** Die Catalog trug eine DOCTYPE, die die OASIS-Catalog-DTD
über's Netz referenzierte (`http://www.oasis-open.org/…/catalog.dtd`).
Saxons Apache-Catalog-Resolver parst die Datei per SAX; der Parser versucht
die DOCTYPE-SYSTEM-id zu holen → oasis-open.org redirectet http→https →
der Resolver-URL-Handler kann kein `https` → `unknown protocol: https`
→ Catalog-Parsing bricht ab → JATS-DTD (`JATS-publishing1.dtd`) wird nicht
aufgelöst → alle Saxon-Schritte mit `-catalog:` scheitern
(xml_typo, xml_to_refs, xml_to_html, xml_to_html_test). Die DOCTYPE ist
rein deklarativ (Catalog braucht keine DTD zum Parsen), Entfernen ist
verlustfrei. Gleiche Fehlerklasse wie die DOCTYPE-Strips in
`validate_xml_rng` (2026-05-19) und im `xml_to_html`-Bereich — nur dass
sie hier die Catalog-Datei selbst, nicht die Inhalts-XML betraf.
**Changes:** Einzeilige Quelländerung an der Catalog-Datei (DOCTYPE
durch erklärenden Kommentar ersetzt). Kaltes `build_all` auf dem
Demo-Artikel (`jds-2026-001-mustermann`) danach vollständig grün.

---

## Abgeschlossene Phasen (Übersicht)

Kern- und Pipeline-Phasen, die in die obigen Entscheidungen mündeten:
Phase 0 (Bug Fixes), 1 (Core System), 2/2b (Lower-Level Cleanup +
Typografie-XSLT), 4/4b (Image Handling + Marker-Syntax), 5 (Template-
Modularisierung), 8 (Scaffold), 9/9b (Stale Detection + Warnings
Framework), 10 (Manual Override), 14 (Manifest Architecture), 15 (File-Task
Pipeline), 16 (Per-Level CFG), 18 (XML Validation), 19 (Output Packaging),
20a (XProc-Migration), 24 (Lua-Filter Audit), 25 (Bibliography Review).
Offene Phasen stehen in `docs/plans/roadmap.md`.