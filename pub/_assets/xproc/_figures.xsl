<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                exclude-result-prefixes="xsl">

  <!--
    Figuren: fig-Label, nolabel-fig -> graphic-mit-Caption, fig-group.
    Extrahiert aus cleanup.xsl (Phase 20a, Aufloesungs-Architektur).
    Eigener p:xslt-Step in cleanup.xpl nach choose(_sections), VOR
    _tables / _blocks / (frueher) cleanup.xsl.

    xsl:mode on-no-match="shallow-copy" ersetzt das Identitaets-Template
    (match="*"), das in cleanup.xsl verbleibt. xsl:output kosmetisch -
    Serialisierung regiert cleanup.xpl p:output (Single Source); in XProc
    wird der Step-Ergebnisbaum als XDM weitergereicht, nicht serialisiert.
  -->
  <xsl:output method="xml" indent="yes"/>
  <xsl:mode on-no-match="shallow-copy"/>
<!-- GRAFIKEN -->

<!-- Grafiken in <fig/> werden automatisch nummeriert -->
<!-- <xsl:template match="fig[not(@fig-type = 'nolabel' or  parent::fig-group)]"> -->
<!-- <xsl:template match="fig[not(@fig-type = 'nolabel') and not(name(..)='fig-group')]"> -->
<xsl:template match="//fig[not(@fig-type = 'nolabel' or parent::boxed-text)]">
	<xsl:copy>
		<xsl:copy-of select="@*"/>
		<label><xsl:if test="/article/@xml:lang='en'">Figure </xsl:if><xsl:if test="/article/@xml:lang='de'">Abbildung </xsl:if><xsl:number level="any" count="fig | boxed-text[@content-type='fig-group']"/></label>
        <xsl:apply-templates/>
	</xsl:copy>
</xsl:template>


<!-- Grafiken ohne Label werden von fig zu graphic umgewandelt und die caption entsprechend verschoben -->
<xsl:template match="//fig[@fig-type = 'nolabel']">
		<xsl:apply-templates/>
</xsl:template>

<xsl:template match="//fig[@fig-type='nolabel']/graphic">
	<xsl:copy>
		<xsl:copy-of select="@*"/>
		<xsl:copy-of select="../caption"/>
        <xsl:apply-templates/>
	</xsl:copy>
</xsl:template>

<xsl:template match="//fig[@fig-type='nolabel']/caption"/>


<!-- FIGURE-GROUPS -->
<xsl:template match="//boxed-text[@content-type = 'fig-group']">
  <fig-group>
		<xsl:copy-of select="@*"/>
		<label><xsl:if test="/article/@xml:lang='en'">Figure </xsl:if><xsl:if test="/article/@xml:lang='de'">Abbildung </xsl:if><xsl:number count="fig | boxed-text[@content-type='fig-group']"/></label>
		<xsl:apply-templates/>
  </fig-group>
</xsl:template>
</xsl:stylesheet>
