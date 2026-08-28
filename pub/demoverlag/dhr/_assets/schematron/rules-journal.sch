<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron" queryBinding="xslt">
  <title>DHR JATS-Basisvalidierung (Demo)</title>

  <!-- Prüft erlaubte article-type Werte -->
  <pattern id="allowed-article-types">
    <rule context="article/@article-type">
      <assert test=". = 'research-article' or . = 'editorial' or . = 'obituary' or . = 'book-review' or . = 'review-essay'">
        Ungültiger article-type: <value-of select="." />.
        Erlaubt: research-article, editorial, obituary, book-review, review-essay.
      </assert>
    </rule>
  </pattern>

  <!-- Prüft DOI-Format (muss auf Zahl enden, darf nicht auf ? enden) -->
  <pattern id="doi-format">
    <rule context="article/front/article-meta/article-id[@pub-id-type='doi']">
      <!-- Prüft, dass der DOI nicht auf ? endet -->
      <assert test="not(contains(., '?'))">
        Ungültiger DOI: <value-of select="." />. DOI darf nicht auf '?' enden.
      </assert>
      <!-- Prüft, dass der DOI mit der korrekten Basis beginnt (flexible Jahreszahl) -->
      <assert test="starts-with(., 'https://doi.org/10.5555/dhr.')">
        Ungültiger DOI: <value-of select="." />. DOI muss mit 'https://doi.org/10.5555/dhr.' beginnen.
      </assert>
      <!-- Prüft, dass der DOI auf eine Zahl endet (Jahreszahl.Nummer) -->
      <assert test="matches(., 'https://doi.org/10.5555/dhr.[0-9]+\.[0-9]+$')">
        Ungültiger DOI: <value-of select="." />. DOI muss auf eine Zahl enden (z.B. https://doi.org/10.5555/dhr.2026.1).
      </assert>
    </rule>
  </pattern>

</schema>