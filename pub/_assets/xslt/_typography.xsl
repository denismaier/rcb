<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:t="http://jndf.local/typo"
	exclude-result-prefixes="xsl xs t">

<!-- ============================================
     TYPOGRAPHY XSLT
     ============================================

     German typography replacements in JATS XML.
     Läuft nach Validierung (RNG + Schematron), vor xml_final.

     Regeln nach typo-replacements.py (Python-Original):
     - Locators + Zahl (S., Anm., Bd., §, …): Punkt + NNBSP + Zahl
     - Englische Jahresangaben (AD, BC, CE, BCE): Jahr + NBSP + Abk.
     - Mehrteilige Abkürzungen (d.h., z.B., u.a., …): mit NNBSP getrennt
     - Bibliographische Refs (Gen + Zahl): mit NBSP getrennt

     Zeichen-Konvention:
     - NNBSP (U+202F) für mehrteilige Abkürzungen und Locators →
       schmaler als ein normales Space, kein Umbruch
     - NBSP  (U+00A0) für Jahres-Abk. (AD/BC/CE/BCE) und Gen →
       Standard non-breaking space

     ============================================ -->

<xsl:output method="xml" indent="yes"/>

<!-- Default: copy all as-is (identity template) -->
<xsl:template match="node()|@*">
  <xsl:copy>
    <xsl:apply-templates select="node()|@*"/>
  </xsl:copy>
</xsl:template>

<!-- ============================================
     TEXT NODE PROCESSING
     ============================================ -->

<!-- priority="1" überstimmt den generischen node()-Identity-Template.
     Ausgenommen:
     - Autor-Namen-Container (name, string-name) — Typo würde Namen wie
       "v. d. Zillingen" zerschießen.
     - Identifier (article-id, pub-id, journal-id, contrib-id, issn, isbn)
       und URLs (email, uri, self-uri, ext-link) — müssen byte-identisch
       bleiben.
     - Code-Elemente (monospace, code, preformat) — Inline-/Block-Code.
     Bewusst NICHT ausgeschlossen: ganz <front>. Damit werden
     article-title, abstract, copyright-statement, license-p
     typografiert (entspricht Python-Original-Verhalten). -->
<xsl:template match="text()[not(ancestor::*[
    self::name or self::string-name or self::contrib-id
    or self::email or self::uri or self::self-uri or self::ext-link
    or self::article-id or self::pub-id or self::journal-id
    or self::issn or self::isbn
    or self::monospace or self::code or self::preformat])]" priority="1">
  <xsl:value-of select="t:typo-replace(.)"/>
</xsl:template>

<!-- ============================================
     TYPOGRAPHY FUNCTION
     ============================================ -->

<!-- Regel-Tabelle. Reihenfolge ist semantisch: mehrteilige Patterns müssen
     vor ihren zweiteiligen Substrings stehen (sonst überschreibt der kürzere
     Match den längeren). Tippfehler im Python-Original (`s?` statt `\s?` in
     Jh. v.d.Z.) ist hier gefixt. -->
<xsl:variable name="rules" as="map(xs:string, xs:string)*">
  <!-- Locators mit Zahl: NNBSP -->
  <xsl:sequence select="map{'p': '(Anm\.)\s?([0-9])',              'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(S\.)\s?([0-9])',                'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(H\.)\s?([0-9])',                'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(§)\s?([0-9])',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(Kap\.)\s?([0-9])',              'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(Nr\.)\s?([0-9])',               'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(Bd\.)\s?([0-9])',               'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(Teilbd\.)\s?([0-9])\s?([0-9])', 'r': '$1&#x202F;$2&#x202F;$3'}"/>

  <!-- Englische Jahresangaben: NBSP -->
  <xsl:sequence select="map{'p': '([0-9])\s?(AD)',                 'r': '$1&#xA0;$2'}"/>
  <xsl:sequence select="map{'p': '([0-9])\s?(BC)',                 'r': '$1&#xA0;$2'}"/>
  <xsl:sequence select="map{'p': '([0-9])\s?(CE)',                 'r': '$1&#xA0;$2'}"/>
  <xsl:sequence select="map{'p': '([0-9])\s?(BCE)',                'r': '$1&#xA0;$2'}"/>

  <!-- Jahreszahl + v. Chr. / n. Chr. (drei Teile NNBSP) -->
  <xsl:sequence select="map{'p': '([0-9]) (v\.)\s?(Chr\.)',        'r': '$1&#x202F;$2&#x202F;$3'}"/>
  <xsl:sequence select="map{'p': '([0-9]) (n\.)\s?(Chr\.)',        'r': '$1&#x202F;$2&#x202F;$3'}"/>

  <!-- Jh. v. d. Z. (vier Teile NNBSP) -->
  <xsl:sequence select="map{'p': '(Jh\.)\s?(v\.)\s?(d\.)\s?(Z\.)', 'r': '$1&#x202F;$2&#x202F;$3&#x202F;$4'}"/>

  <!-- 3. Auflage etc. (Punkt + NNBSP) -->
  <xsl:sequence select="map{'p': '([0-9]+)\.\s?(Aufl\.)',          'r': '$1.&#x202F;$2'}"/>

  <!-- dreiteilige Abkürzungen (NNBSP) — vor den zweiteiligen! -->
  <xsl:sequence select="map{'p': '(i\.)\s?(d\.)\s?(R\.)',          'r': '$1&#x202F;$2&#x202F;$3'}"/>
  <xsl:sequence select="map{'p': '(Jh\.)\s?(v\.)\s?(Chr\.)',       'r': '$1&#x202F;$2&#x202F;$3'}"/>
  <xsl:sequence select="map{'p': '(Jh\.)\s?(n\.)\s?(Chr\.)',       'r': '$1&#x202F;$2&#x202F;$3'}"/>
  <xsl:sequence select="map{'p': '(Jh\.)\s?(u\.)\s?(Z\.)',         'r': '$1&#x202F;$2&#x202F;$3'}"/>
  <xsl:sequence select="map{'p': '(v\.)\s?(d\.)\s?(Z\.)',          'r': '$1&#x202F;$2&#x202F;$3'}"/>

  <!-- 19. Jahrhundert etc. (Punkt + NNBSP) -->
  <xsl:sequence select="map{'p': '([0-9]+)\.\s(Jh\.)',             'r': '$1.&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '([0-9]+)\.\s(Jahrhundert)',      'r': '$1.&#x202F;$2'}"/>

  <!-- zweiteilige Abkürzungen: NNBSP -->
  <xsl:sequence select="map{'p': '(d\.)\s?(h\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(s\.)\s?(o\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(s\.)\s?(u\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(z\.)\s?(B\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(z\.)\s?(T\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(u\.)\s?(a\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(v\.)\s?(a\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(m\.)\s?(E\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(s\.)\s?(A\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(u\.)\s?(Z\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(v\.)\s?(Chr\.)',                'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(n\.)\s?(Chr\.)',                'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(u\.)\s?(ö\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(a\.)\s?(M\.)',                  'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(i\.)\s?(Br\.)',                 'r': '$1&#x202F;$2'}"/>
  <xsl:sequence select="map{'p': '(hg\.)\s?(v\.)',                 'r': '$1&#x202F;$2'}"/>

  <!-- Biblische Bücher: NBSP -->
  <xsl:sequence select="map{'p': '(Gen)\s?([0-9])',                'r': '$1&#xA0;$2'}"/>
</xsl:variable>

<xsl:function name="t:typo-replace" as="xs:string">
  <xsl:param name="input" as="xs:string"/>
  <xsl:iterate select="$rules">
    <xsl:param name="text" as="xs:string" select="$input"/>
    <xsl:on-completion select="$text"/>
    <xsl:next-iteration>
      <xsl:with-param name="text" select="replace($text, ?p, ?r)"/>
    </xsl:next-iteration>
  </xsl:iterate>
</xsl:function>

</xsl:stylesheet>
