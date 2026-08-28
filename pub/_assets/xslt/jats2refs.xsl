<?xml version="1.0" encoding="UTF-8"?>
<!-- jats2refs.xsl — OJS-Plain-Text-Referenzen.
     Pro <ref> eine Zeile, Inhalt aus <mixed-citation>. <italic> und anderes
     Inline-Markup fallen über <xsl:output method="text"> weg; normalize-space()
     kollabiert Serialisierungs-Umbrüche/Whitespace zu einfachen Leerzeichen.
     Keine <ref>-Nummer, kein <title>. Quelle ist das published XML
     (xml_publish), gleich wie xml_to_output. -->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" encoding="UTF-8"/>

  <xsl:template match="/">
    <xsl:for-each select="//ref-list/ref[mixed-citation]">
      <xsl:value-of select="normalize-space(mixed-citation)"/>
      <xsl:text>&#10;</xsl:text>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>