# XProc Cleanup Test-Harness

Ursprünglich isolierter Spielplatz für die Phase-20-Migration von
`cleanup.xsl` zu einer XProc-Pipeline. Die Pipeline ist am **2026-07-08 nach
Production portiert** ([`pub/_assets/xproc/`](../../pub/_assets/xproc/))
und in `pub/rcb.rake` (`xml_clean`-Step, Morgana) angeschlossen. Die
monolithische `cleanup.xsl` ist in Production gelöscht.

Dieses Verzeichnis ist jetzt die **Regression-Suite** für die Production-
Pipeline: `tests.bat` ruft Morgana direkt gegen
[`../../pub/_assets/xproc/cleanup.xpl`](../../pub/_assets/xproc/cleanup.xpl)
auf und vergleicht gegen die geblessten Baselines in `expected/`. Keine
doppelte Pflege — die Module leben kanonisch in Production; hier liegen nur
Test-Inputs, erwartete Outputs und der Runner. Gate = semantische Korrektheit
(s. Decision Log 2026-06-26; byte-Parität zur Produktion ist kein Gate).

## Dateien

- `tests.bat` — Test-Runner. Ruft `../../pub/_assets/xproc/cleanup.xpl`
  pro Case auf. Linearere Liste von Tests als `:labels`. Ohne Argument: alle
  Tests. Mit Test-Namen als Argument (Substring): nur die.
- `inputs/<case>.xml` — Test-Case-Inputs. Synthetische JATS-Minimal-Samples,
  jeder Case triggert gezielt eine Cleanup-Regel (oder bewusst keine).
  Namensschema: `NN-rule-name.xml` (z.B. `01-minimal.xml`, `02-section-numbering.xml`).
- `expected/<case>.xml` — Referenz-Outputs pro Case (gleicher Basename wie
  in `inputs/`). Byte-identisch erwartet beim Durchlauf der Production-
  Pipeline. Eingecheckt.
- `out/<case>.xml` — Generierte Outputs. Gitignored.
- `identity.xpl` / `identity-with-load.xpl` — Debug-Hilfs-Pipelines (nicht
  Teil der Production-Pipeline); `04-load-morgana` nutzt `identity-with-load.xpl`.
- `jats-dtd/` — alte DTD-Kopie (wird von Tests nicht genutzt; `CATALOG` in
  `tests.bat` zeigt auf `../../pub/_assets/jats-dtd/`).

## Workflow

```
.\tests                                       # alle Tests
.\tests 01-minimal                            # nur dieser Test
.\tests 01-minimal 02-section-numbering       # mehrere

REM "Blessen" eines neuen expected (manuell):
copy out\01-minimal.xml expected\01-minimal.xml
```

Tests sind als `:labels` am Ende von `tests.bat` definiert. Neuer Test
= neues Label + ein `call :<name>`-Eintrag im `:run_all`-Block. Optionen
werden per `-option:name=value` an Morgana mitgegeben, Output-Namen
encoden die Variante.

## Test-Case-Strategie

Jeder Case in `inputs/` triggert gezielt eine `cleanup.xsl`-Regel (oder
bewusst keine). So bleibt der Diff sauber zuordenbar wenn beim Extrahieren
einer Regel etwas schief geht.

Geplante Case-Reihenfolge (wächst mit den Extraktionen):

| Case | Input-Inhalt | Zweck |
|---|---|---|
| `00-pi-survival` | `<article>` mit PIs (article-level, in `<sec>`, inline in `<p>`) | PI-Survival-Beweis: PIs überleben alle Module + XProc-Primitive (PI/identity/article-Templates in cleanup.xsl sind gefallen) |
| `01-minimal` | minimales `<article>` mit `<front>` + `<body><p>` | Baseline ohne Trigger |
| `02-section-numbering` (+ `-nonum`) | + `<body><sec><title>...` | Section-Numbering-Regel + Toggle |
| `03-doctype-baseline` | internal DTD subset | DTD-Default-Expansion mechanisch (Suppress-Beweis) |
| `04-boxed-text-jats` | externe JATS-DTD via Catalog | DTD-Default-Suppress auf `<boxed-text>` (Morgana) |
| `05-back-moves` | `<sec sec-type="ref-list">` + `<sec sec-type="app-*">` + `<back>` | Ref-List/Appendix nach Back (`_back-moves.xsl`) |
| `06-figures` | `<fig>` labeled + `fig[@fig-type='nolabel']` + `boxed-text[fig-group]` | `_figures.xsl` |
| `07-tables` | `boxed-text[labeled]` + `boxed-text[position=float]` | `_tables.xsl` (labeled + floating) |
| `08-parallel` | `boxed-text[parallel]` + `parallel-*-rtl` + `righttoleft` | `_tables.xsl` (parallel + RTL) |
| `09-blocks` | disp-quote/rtlblockquote/epigraph/preformat/attrib | `_blocks.xsl` |
| `10-verse` | verse/verse-centered/verse-line+attrib/parallel-verse | `_blocks.xsl` (verse + parallel-verse) |
| `11-strips` | `p[specific-use=wrapper]` + `fn/label` + `aff[@id='aff-'/'']` | XProc-Strips (`p:unwrap`/`p:delete`/`p:viewport`) |

Pro neuer Case-Extraktion:
1. `inputs/<case>.xml` anlegen
2. neuen `:label`-Block in `tests.bat` (morgana + fc); im `:run_all` aufnehmen
3. `.\tests <case>` laufen — produziert `out/<case>.xml`
4. Output prüfen, bei passendem Verhalten: `copy out\<case>.xml expected\<case>.xml`
4. Template-Block aus `cleanup.xsl` in eigene Mini-XSLT extrahieren
5. `run.bat` (gesamt) + `diff.bat` (gesamt) — alle Cases müssen weiter byte-identisch sein

So bleibt jede Extraktion ein eigener, isoliert verifizierbarer Commit.

## Iterationen der Pipeline

Orthogonal zu den Test-Cases evolviert die Pipeline (`cleanup.xpl`):

| Iter | Pipeline | Erwartete Wirkung auf Cases |
|---|---|---|
| 1 | nur `<p:identity/>` | alle Cases: Output = Input (modulo Serialisierungs-Norm) |
| 2 | + `<p:xslt>` mit `cleanup.xsl` | Cases triggern jeweils ihre Regel; expected wird neu geblesst |
| 3 | + explizites `<p:load>` mit `mox:expand-default-attributes: false()` (Suppress) | wirkt nur auf Cases mit DOCTYPE |
| 4ff | XSLT-Logik wird schrittweise aus `cleanup.xsl` extrahiert | Cases müssen byte-identisch bleiben |

## Voraussetzungen

- **Morgana XProc 3** (xml-project, https://www.xml-project.com/morganaxproc-iii/)
  als CLI im PATH (`morgana` ruft die `.bat` auf, die intern Java startet).
- **XSLT-Prozessor im Morgana-Classpath:** Morgana bringt keinen XSLT-Prozessor
  mit. Saxon-JAR muss in den `_lib`-Ordner der Morgana-Installation. Saxon HE
  reicht für unseren Bedarf. Falls Saxon PE oder EE: zusätzlich die
  License-Datei in `_lib` legen.
- **Saxon-Catalog** (für DTD-Auflösung) ist später relevant — sobald wir
  Cases mit DOCTYPE einsetzen. Morganas `-catalogs=`-Flag setzt das.

## Morgana-Aufruf

```
morgana cleanup.xpl -input:source=inputs/<case>.xml -output:result=out/<case>.xml \
        -catalogs=path/to/jats-catalog.xml
```

Reihenfolge: Pipeline-Datei als erstes positionelles Argument, Optionen
danach. (Anders als bei Saxon's `transform`, wo die Reihenfolge egal ist.)

CLI-Pattern (aus der Morgana-Doku):
- `-input:port-name=path` befüllt Input-Ports
- `-output:port-name=path` zieht Output-Ports raus
- `-option:name=value` setzt Pipeline-Optionen
- `-catalogs=path` setzt XML-Catalog (semikolon-getrennt für mehrere)

## Diff-Verifikation

Tests integrieren `fc /b` direkt — kein separater Diff-Schritt nötig.
`tests.bat` zeigt am Ende eine Summary (`N passed, M failed`).

Für unified diff mit Zeilennummern:
```
git diff --no-index expected\01-minimal.xml out\01-minimal.xml
```

Wenn nicht byte-identisch: Diff anschauen, ob's semantisch oder nur
Serialisierung (Encoding-Header, Indent, BOM, Line-Endings) ist. Bei
Serialisierungs-Unterschieden: neue Norm als Baseline akzeptieren
(`expected/NN.xml` neu blessen).

## PowerShell-Hinweis

PowerShell sucht Befehle nicht im aktuellen Verzeichnis. Statt `tests`
also `.\tests` (oder `.\tests.bat`) aufrufen.
