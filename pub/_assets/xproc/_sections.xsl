<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <!--
    Section numbering: three levels.
    Extracted aus cleanup.xsl (Phase 20). Suppression-Logik
    (vormals via $nonumheadings-Param + <xsl:if>) wandert in
    die XProc-Pipeline: cleanup.xpl entscheidet via <p:choose>,
    ob dieser Step ueberhaupt laeuft.

    Kein Predicate, matcht all body/sec. Reihenfolge in cleanup.xpl:
    _back-moves.xsl laeuft VOR diesem Step, verschiebt ref-list/app-*
    secs nach <back> — beim Eintritt hier sind sie schon weg, sections
    nummeriert nur die verbliebenen normalen body-secs. Frueher (sections
    VOR back-moves) bekamen ref-list/app ein Label, das beim Move ins
    <ref-list>/<app> mitwanderte — Regression, die nur auftrat weil die
    Two-Pass-Split die Single-Pass-Prioritaet (Remove gewinnt ueber
    Section-Numbering) aufhob. Flip nach back-moves-first loest es ohne
    Predicate. Siehe Roadmap Decision Log 2026-06-26.
  -->

  <xsl:output method="xml" indent="yes"/>
  <xsl:mode on-no-match="shallow-copy"/>

  <xsl:template match="body/sec">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <label><xsl:number count="body/sec"/></label>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="body/sec/sec">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <label><xsl:number count="body/sec"/>.<xsl:number count="body/sec/sec"/></label>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="body/sec/sec/sec">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <label><xsl:number count="body/sec"/>.<xsl:number count="body/sec/sec"/>.<xsl:number count="body/sec/sec/sec"/></label>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
