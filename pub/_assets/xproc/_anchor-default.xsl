<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                exclude-result-prefixes="xsl">

  <!--
    Anchor-Default-Normalize (Phase 20, Nach-20a). JATS-Default fuer
    @position auf boxed-text ist 'float' (JATS-display1.ent:393); die
    Pipeline suppressiert die DTD-Default-Expansion am Load-Step
    (mox:expand-default-attributes=false()), sodass fehlendes @position
    implizit 'anchored' bedeutet. Dieser Step macht das explizit:
    boxed-text ohne @position bekommt position="anchor". boxed-text mit
    @position (float/anchor/margin/background) faellt via shallow-copy
    unveraendert durch -> idempotent.

    Prototyp-Scope: nur boxed-text. Die uebrigen display-atts-Elemente
    (fig, fig-group, table-wrap, ...) bleiben unangetastet, bis ihre
    downstream-Implikationen geprueft sind. boxed-text ist der
    Naturprototyp, weil es die float-strip-Bruchstelle traegt
    (_tables.xsl: boxed-text[@position='float'] strippt den Wrapper;
    safe nur wegen Suppress).

    Laeuft als eigener p:xslt-Step NACH _blocks (und _tables/_figures):
    erst dann ueberleben nur noch 'plain' boxed-text sowie
    parallel-verse-Wrapper (ohne position) -> genau die Zielmenge.
    _tables-erzeugte <table-wrap position="float"> tragen bereits
    position und werden von diesem Step (Scope boxed-text) nicht
    angetastet. Siehe Plan + Roadmap Phase 20c / Decision Log 2026-07-03.
    Serialisierung regiert cleanup.xpl p:output.
  -->
  <xsl:output method="xml" indent="yes"/>
  <xsl:mode on-no-match="shallow-copy"/>

  <xsl:template match="boxed-text[not(@position)]">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:attribute name="position">anchor</xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>