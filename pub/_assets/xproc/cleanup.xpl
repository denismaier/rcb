<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:mox="http://www.xml-project.com/morganaxproc"
  version="3.0"
  name="cleanup">

  <!-- Serialisierung liegt hier (Single Source). cleanup.xsl ist
       aufgeloest (Phase 20a Endzustand): die Content-Transforms laufen
       als eigene p:xslt-Module (_back-moves/_sections/_figures/_tables/
       _blocks), die verbleibenden Strips als XProc-Primitive weiter
       unten. Damit gibt es keinen "letzten" XSLT-Step mehr, dessen
       xsl:output regieren wuerde. Siehe Plan / Roadmap 20a. -->
  <p:output port="result"
    serialization="map{
    'method':'xml',
    'indent':true(),
    'doctype-system':'JATS-publishing1.dtd',
    'doctype-public':'-//NLM//DTD JATS (Z39.96) Journal Publishing DTD v1.2 20190208//EN',
    'suppress-indentation':(xs:QName('named-content'),xs:QName('italic'),xs:QName('underline'),xs:QName('p'))
  }" />
  <p:option name="nonumheadings" select="''" />
  <p:option name="source-href" required="true" />

  <!-- Source via explizitem <p:load> statt CLI -input:source=, damit die
       mox:-parameters-Map am Load-Step greift: DTD-Default-Expansion
       suppress'en (mox:expand-default-attributes=false()).
       Precondition (Achim 2026-06-25): dtd-validate=false UND
       mox:ignore-external-dtd=false — beides Defaults, hier erfuellt.
       href dynamisch pro Case via -option:source-href='inputs/XX.xml'
       (XPath-String-Literal, siehe reference_morgana_setup). Option ist
       required — die Pipeline hat keine Default-Source, fehlt sie, bricht
       Morgana beim Start (fail-loud statt stiller Falsch-Input).
       Siehe identity-with-load.xpl + Roadmap Phase 20c / Decision Log
       2026-06-25. -->
  <p:load>
    <p:with-option name="href" select="$source-href" />
    <p:with-option name="parameters"
      select="map{
      xs:QName('mox:expand-default-attributes'): false()
    }" />
  </p:load>

  <p:message select="Cleanup Pipeline is running" />

  <p:xslt message="Applying _back-moves.xsl">
    <p:with-input port="stylesheet">
      <p:document href="_back-moves.xsl" />
    </p:with-input>
  </p:xslt>

  <p:choose>
    <p:when test="$nonumheadings = 'true'">
      <p:identity message="Skipping section numbering (nonumheadings=true)" />
    </p:when>
    <p:otherwise>
      <p:xslt message="Applying _sections.xsl">
        <p:with-input port="stylesheet">
          <p:document href="_sections.xsl" />
        </p:with-input>
      </p:xslt>
    </p:otherwise>
  </p:choose>

  <p:xslt message="Applying _figures.xsl">
    <p:with-input port="stylesheet">
      <p:document href="_figures.xsl" />
    </p:with-input>
  </p:xslt>

  <p:xslt message="Applying _tables.xsl">
    <p:with-input port="stylesheet">
      <p:document href="_tables.xsl" />
    </p:with-input>
  </p:xslt>

  <p:xslt message="Applying _blocks.xsl">
    <p:with-input port="stylesheet">
      <p:document href="_blocks.xsl" />
    </p:with-input>
  </p:xslt>

  <!-- Anchor-Default-Normalize (Phase 20c, 2026-07-03): boxed-text ohne
       @position bekommt position="anchor" — macht das implizite 'anchored'
       (gesetzt via DTD-Default-Suppress am Load-Step) explizit. Eigener
       p:xslt-Step NACH _blocks: erst dann ueberleben nur noch plain
       boxed-text sowie parallel-verse-Wrapper (ohne position). Idempotent
       (boxed-text mit @position faellt durch shallow-copy). Prototyp-Scope
       boxed-text; siehe _anchor-default.xsl + Roadmap 20c. -->
  <p:xslt message="Applying _anchor-default.xsl">
    <p:with-input port="stylesheet">
      <p:document href="_anchor-default.xsl" />
    </p:with-input>
  </p:xslt>

  <!-- Residuum-Strips als XProc-Primitive (Phase 20a Endzustand):
       cleanup.xsl ist aufgeloest — die letzten drei Regeln werden nativ
       in XProc ausgefuehrt statt als XSLT. Grosse Content-Transforms
       bleiben XSLT-Module (_back-moves/_sections/_figures/_tables/
       _blocks); die kleinen Strips zeigen XProc-Primitive.
       PI-/Identitaets-/article-Templates fallen ganz: xsl:mode
       on-no-match="shallow-copy" der Module + diese Primitive kopieren
       PIs und nicht gematchte Elemente implizit — bewiesen durch
       Case 00-pi-survival (PIs ueberleben alle Paesse + Primitive). -->
  <p:group name="strips">
    <p:message select="Applying strips"/>

    <p:unwrap match="//p[@specific-use='wrapper']" />

    <p:delete match="/article/back/fn-group/fn/label" />

    <p:viewport match="aff[@id='aff-' or @id='']">
      <p:delete match="@id" />
    </p:viewport>
    
  </p:group>


</p:declare-step>