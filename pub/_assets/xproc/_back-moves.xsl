<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                exclude-result-prefixes="xsl">

  <!--
    Back-Moves: ref-list und Appendix (app-*) aus dem Body in den <back>
    verschieben. Extrahiert aus cleanup.xsl (Phase 20, 20a-Aufloesungs-Architektur).
    Laeuft als erster p:xslt-Step in cleanup.xpl VOR _sections.xsl
    (Reihenfolge-Flip 2026-06-26: back-moves verschiebt ref-list/app-*
    secs vorm Nummerieren weg). cleanup.xsl ist aufgeloest; nachfolgend
    laufen _sections/_figures/_tables/_blocks + die XProc-Strips.

    xsl:mode on-no-match="shallow-copy" kopiert nicht gematchte Knoten
    (frueher das match="*" Identitaets-Template in cleanup.xsl). xsl:output
    ist kosmetisch, Serialisierung regiert cleanup.xpl p:output (Single
    Source); in XProc wird der Step-Ergebnisbaum als XDM weitergereicht.
  -->
  <xsl:output method="xml" indent="yes"/>
  <xsl:mode on-no-match="shallow-copy"/>

<!-- MOVE STUFF TO BACK -->

<!-- ref list simple wrapper, for legacy compat, -->
<xsl:template match="//body/sec[@sec-type = 'ref-list']" mode="rename">
	<ref-list id="{generate-id()}">
	  <xsl:apply-templates/>
	</ref-list>
</xsl:template>

<!-- ref list wrapper  -->
<xsl:template match="//body/sec[@sec-type = 'ref-list-wrapper']" mode="rename">
	<ref-list id="{generate-id()}" content-type="wrapper">
	  <xsl:apply-templates/>
	</ref-list>
</xsl:template>

<xsl:template match="//sec[@sec-type = 'ref-list' or @sec-type='ref-list-wrapper']/sec[@sec-type = 'ref-list']">
	<ref-list id="{generate-id()}">
		<xsl:apply-templates/>
	</ref-list>
</xsl:template>

<xsl:template match="//sec[@sec-type = 'ref-list' or @sec-type='ref-list-wrapper']/sec[@sec-type = 'ref-list-shorthands']">
	<ref-list id="{generate-id()}" content-type='shorthands'>
		<xsl:apply-templates/>
	</ref-list>
</xsl:template>

<xsl:template match="//sec[@sec-type = 'ref-list']/p">
	<ref>
		<mixed-citation>
			<xsl:apply-templates/>
		</mixed-citation>
	</ref>
</xsl:template>

<!-- Siglen -->
<xsl:template match="//sec[@sec-type = 'ref-list-shorthands']/def-list">
	<xsl:apply-templates/>
</xsl:template>

<xsl:template match="//sec[@sec-type = 'ref-list-shorthands']/def-list/def-item">
  <ref>
	<xsl:apply-templates/>
  </ref>
</xsl:template>

<xsl:template match="//sec[@sec-type = 'ref-list-shorthands']/def-list/def-item/term">
  <label>
	<xsl:apply-templates/>
  </label>
</xsl:template>

<xsl:template match="//sec[@sec-type = 'ref-list-shorthands']/def-list/def-item/def">
	<xsl:apply-templates/>
</xsl:template>

<xsl:template match="//sec[@sec-type = 'ref-list-shorthands']/def-list/def-item/def/p">
  <mixed-citation>
	<xsl:apply-templates/>
  </mixed-citation>
</xsl:template>

<!-- Appendix sections -->
<xsl:template match="//body/sec[starts-with(@sec-type, 'app-')]" mode="rename">
	<app id="{generate-id()}" content-type="{substring-after(@sec-type, 'app-')}">
		<xsl:apply-templates/>
	</app>
</xsl:template>


<!-- remove from body -->
<xsl:template match="//body/sec[@sec-type = 'ref-list']"></xsl:template>
<xsl:template match="//body/sec[@sec-type = 'ref-list-wrapper']"></xsl:template>

<xsl:template match="//body/sec[starts-with(@sec-type, 'app-')]"></xsl:template>


<xsl:template match="back">
	<xsl:copy>
		<xsl:apply-templates select="@*|node()[not(self::ref-list)]"/>
		<xsl:if test="//body/sec[starts-with(@sec-type, 'app-')]">
			<app-group>
				<xsl:apply-templates select="//body/sec[starts-with(@sec-type, 'app-')]" mode="rename"/>
			</app-group>
		</xsl:if>
		<xsl:apply-templates select="ref-list"/>
		<xsl:apply-templates select="//body/sec[@sec-type = 'ref-list']" mode="rename"/>
		<xsl:apply-templates select="//body/sec[@sec-type = 'ref-list-wrapper']" mode="rename"/>
	</xsl:copy>
</xsl:template>
</xsl:stylesheet>
