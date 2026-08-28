# Article Workflow — vom Autoren-DOCX zum fertigen Artikel

Geführte Schritt-für-Schritt-Checkliste für den Editor-Durchlauf eines
neuen Artikels. Referenz für Details bleibt `pub/README.md`; hier
steht die *Reihenfolge* und die praktischen Fallstricke.

---

## Schritt 1 — Artikel scaffolden

Produktionsartikel leben unter `pub/bop/jndf/volume_<jahr>/` (lokal,
nicht getrackt); synthetische Fixtures unter
`pub/demoverlag/<journal>/volume_<jahr>/` (getrackt). Für einen echten
Artikel scaffoldest du im Produktions-Band, für Experimente im
Demo-Verlag:

```
cd pub/bop/jndf/volume_2026             # Produktion (lokal)
# oder: cd pub/demoverlag/jds/volume_2026   # Demo (getrackt)
rcb-dev init_article
```

> Ein neuer Produktions-Band (z.B. `volume_2027/`) braucht ein
> Volume-Level `metadata.yaml` + `rcb.rake` — kopiere sie aus einem
> bestehenden Band (Demo oder Produktion) als Vorlage. Sie sind Teil
> des Inhalts und bleiben lokal/ungetrackt.

Prompts:
- **Article number** — Vorschlag ist die nächste freie Nummer, meist ok.
- **Author last name** — Nachname des Autors (Pflicht).

Daraus baut `init_article` den Basename `<abbrev>-<year>-<num>-<slug>`
und legt an: `rcb.config.rb`, `rcb.rake` (mit `full_article_info`),
`metadata.yaml` (aus Template), `source/`.

> Danach: `cd <basename>/`. Alle weiteren Befehle laufen auf
> Artikel-Ebene.

---

## Schritt 2 — Word-Manuskript vorbereiten

DOCX nach `source/<basename>.docx` kopieren. **Vorher** im Word
aufräumen:

1. **Titel mit Word-Absatzstil "Title" taggen.**
   Pandoc liest Metadaten aus *stiliierten Absätzen*, nicht aus
   `docProps/core.xml`. Nur so — falls `extract_metadata` genutzt
   wird (Schritt 4) — kommt der Titel automatisch ins Front-Matter.

2. **Byline aus dem Body löschen** (Autor / Affiliation / Email).
   Diese Felder gehören ins Front-Matter und werden aus `metadata.yaml`
   gespeist. Stehen sie noch im Body, werden sie *doppelt* gerendert.
   Es gibt (noch) keinen Body-Filter, der sie automatisch entfernt —
   Backlog.

3. **Bilder nicht einbetten.** Embedded images werden nicht
   unterstützt (`--extract-media` ist bewusst nicht gesetzt). Bilder
   als Einzeldateien nach `source/images/`, referenziert via
   Image-Marker:

   ```
   <<IMG: bild.jpg | caption: "…" | float: true | type: figure>>
   ```

   Pfad = reiner Dateiname, kein `images/`-Präfix. Siehe README
   "Image Markers" für die Quirks (Typografie-Anführungszeichen etc.).

---

## Schritt 3 — `metadata.yaml` von Hand ausfüllen

Metadaten werden normalerweise händisch gepflegt. Felder (Template:
`_assets/metadata/metadata-template-article.yaml`):

| Feld | Wert |
|------|------|
| `title` | Titel aus dem Manuskript eintragen |
| `author` | `surname`, `given-names`, `affiliation`, `email` |
| `lang` | `de` / `en` / `fr` / `he` |
| `article.type` | `research-article`, `book-review`, … |
| `article.doi_article_number` | Artikel-Nummer im Band (DOI wird daraus konstruiert) |
| `date.month` | numerisch 1–12 |
| `copyright.holder` | Autor-Vollname(n), kommagetrennt |
| `tags` | Schlagworte |

`_extract.protect:` pflegen — Felder, die bei einem späteren
Re-Extract *nicht* überschrieben werden sollen. Initial leer; sobald
der Titel stimmt, `[title]` eintragen.

> `_extract.protect` ist rein Nutzer-definiert — kein Default, kein
> Code schreibt ihn zurück. Er schützt nur, was du einträgst.

---

## Schritt 4 — `extract_metadata` (optional, nur bei DOCX-Änderungen)

Im Normalfall nicht nötig — Schritt 3 deckt die Metadaten ab. Nur
relevant, wenn man Felder automatisch aus dem Manuskript ziehen will
bzw. **nach einer DOCX-Änderung** den Titel neu pullen möchte:

```
rcb-dev extract_metadata
```

Interactive: zeigt Proposed Changes (`[ADD]` / `[UPDATE]` /
`[SKIPPED - protected]`), fragt `[y/N]`. Auto-Apply mit
`rcb-dev --yes extract_metadata` oder `CFG['extract_auto_apply'] = true`.

De facto kommt (heute) **nur der Titel** — und nur, wenn Schritt 2.1
gemacht wurde. Bei Apply wird `metadata.yaml.bak` angelegt.

**Wichtig:** `extract_metadata` schreibt via `to_yaml` und strippt
dabei die Kommentar-Hinweise aus dem Template. Deshalb Schritt 3
*vor* dem ersten Extract erledigen — dann sind die Felder schon
gepflegt und nur der Kommentar-Verlust bleibt, nicht auch fehlende
Werte.

**Danach:** Titel in `metadata.yaml` prüfen/kuratieren und
`_extract.protect: [title]` setzen, damit ein späterer Re-Extract ihn
nicht überschreibt.

> Nicht Teil von `build_all` (interaktiv). Nur bei
> Metadata-Änderungen am Manuskript neu laufen lassen.

---

## Schritt 5 — `build_test` zuerst

```
rcb-dev build_test
```

Erzeugt XML + Test-HTML (mit `galley.css`) + Test-PDF + Bilder. Die
Test-Outputs sind zum Durchsehen da:

- `output/html/test-<basename>.html`
- `output/pdf/<basename>-test.pdf`

Front-Matter, Byline, Abstract, Bilder, Fussnoten prüfen. Iterieren:
Metadaten in `metadata.yaml` oder Inhalt im Word/MD-Override
anpassen, `build_test` neu laufen (inkrementell via mtime).

> Immer `build_test` vor `build_all` — produzierte Outputs erst, wenn
> die Test-Variante sauber ist.

---

## Schritt 6 — MD-Override (wenn die Auto-Konversion unbrauchbar ist)

Pandoc schreibt das rohe Markdown nach
`.build/md/01-md-raw-<basename>.md`. Wenn das schneller im MD zu
korrigieren ist als im DOCX, einen Override anlegen:

```
rcb-dev promote_md
```

`promote_md` kopiert das rohe MD nach `source/<basename>.md` (Dependency
auf `source_to_md` stellt sicher, dass es aktuell ist). Einmalig —
existiert der Override schon, weigert sich der Task, um Hand-Edits nicht
zu überschreiben; dann direkt `source/<basename>.md` editieren.

`source/<basename>.md` editieren. Beim nächsten Build nimmt der
Override-Mechanismus (Lade-Zeit-Fork im `source_to_md`-File-Task)
die hand-edierte MD statt der Auto-Konversion. Sidefiles signalisieren
den Zustand:

| Datei | Bedeutung |
|-------|-----------|
| `01-md-raw-<basename>.md.compare` | Override ist aktuell |
| `01-md-raw-<basename>.md.stale` | DOCX ist neuer als Override (mtime) — mergen prüfen |

Bei `.stale` feuert `RCB.warn` und erscheint in der Build-Summary.
Diff die `.stale` gegen den Override und entscheide, ob
Autorenänderungen übernommen werden.

---

## Schritt 7 — `build_all`

```
rcb-dev build_all
```

Baut Publish- + Test-Varianten. Outputs in `output/`:

- `output/xml/<basename>.xml` (Publish-Variante, ohne ConTeXt-PIs, für OJS)
- `output/html/<basename>.html` (Produktion, `galley.css` serverseitig injiziert)
- `output/pdf/<basename>.pdf` (Produktion)
- `output/xml/<basename>.zip` — on-demand via `rcb-dev xml_to_zip` (nur bei Bildern)

Validierung (RNG + Schematron) gate-t automatisch alle Downstream-Outputs
über den File-Task-DAG — wenn `xml_final` nicht validiert, baut nichts
fertiges.

---

## Gotchas — Kurzfassung

- **Titelstil im Word taggen**, falls `extract_metadata` genutzt wird.
- **`metadata.yaml` von Hand füllen** — und falls doch `extract_metadata`
  läuft: *vorher* füllen, sonst strippt `to_yaml` die Kommentar-Hinweise.
- **Byline aus dem Word-Body löschen**, sonst doppelt im Front-Matter.
- **`_extract.protect: [title]`** setzen, sobald der Titel stimmt.
- **`build_test` vor `build_all`.**
- **MD-Override via `rcb-dev promote_md`** anlegen (einmalig; existiert
  er schon, direkt editieren).
- **Bilder nie einbetten** — `source/images/` + Image-Marker.