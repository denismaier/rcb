<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                exclude-result-prefixes="xsl">

  <!--
    Tabellen: labeled boxed-text -> table-wrap position=float + Label,
    floating boxed-text position=float, PARALLEL-Texte (parallel +
    parallel-*-rtl) mit colgroup/dir:rtl, RTL-Paragraphen (righttoleft).
    Extrahiert aus cleanup.xsl (Phase 20a). Eigener p:xslt-Step in
    cleanup.xpl nach _figures, VOR _blocks.

    Two-Pass-Sicherheit: boxed-text wird von _tables UND _blocks gematcht,
    aber ueber disjunkte content-types (labeled/float/parallel*/righttoleft
    hier vs. blockquote/epigraph/verse/... in _blocks). Kein Ueberlapp im
    Einzelpass; hier shallow-copy fuer alle nicht-Tabelle-Elemente.
    xsl:output kosmetisch, Serialisierung regiert cleanup.xpl p:output.
  -->
  <xsl:output method="xml" indent="yes"/>
  <xsl:mode on-no-match="shallow-copy"/>
<!-- TABLES -->
<!-- remove the wrapper -->
<xsl:template match="boxed-text[@content-type = 'labeled']">
	<xsl:apply-templates/>
</xsl:template>

<!-- add @position and label element -->
<xsl:template match="boxed-text[@content-type = 'labeled']/table-wrap">
	<table-wrap position="float">
		<label>
			<xsl:if test="/article/@xml:lang='en'">
				Table
			</xsl:if>
			<xsl:if test="/article/@xml:lang='de'">
				Tabelle
			</xsl:if>
			<xsl:number count="boxed-text[@content-type = 'labeled']"/>
		</label>
		<xsl:apply-templates/>
	</table-wrap>
</xsl:template>


<!-- FLOATING TABLES -->

	<xsl:template match="boxed-text[@position = 'float']/table-wrap">
		<table-wrap>
		  <!-- Unnötiger Test, wir wissen das ja schon -->
		  <!-- eventuell könnte man überlegen, ob das robuster sein soll, also andere werte noch mitnehmen? -->
		  <!-- <xsl:if test="starts-width(../@content-type, 'parallel')"> --> 
			<xsl:attribute name="position">
				<xsl:text>float</xsl:text>
			</xsl:attribute>
		  <!-- </xsl:if> -->
		  <xsl:copy-of select="@*|../@*[not(name() = 'position')]" />
		  <xsl:apply-templates />
		</table-wrap>
	</xsl:template>
	
	<xsl:template match="boxed-text[@position = 'float']">
	  <xsl:apply-templates />
</xsl:template>

<!-- PARALLEL TEXTS -->
<!-- 
Generell wäre hier zu fragen, ob dieser Move mit der col group notwendig ist, 
oder ob man nicht einfach über den content-type gehen will. (ZUMAL DAS NICHT FUNKTIONIERT.)
Es braucht dann halt vielleicht aber mehr patterns bei der Darstellung... 
-->

<!-- captions ohne Inhalt entfernen -->
<xsl:template match="boxed-text[@content-type = 'parallel' 
									or @content-type = 'parallel-left-rtl'
									or @content-type = 'parallel-right-rtl'
									or @content-type = 'parallel-both-rtl'
									]/table-wrap/caption[not(string(p))]">
</xsl:template>
								


	<xsl:template match="boxed-text[@content-type = 'parallel' 
									or @content-type = 'parallel-left-rtl'
									or @content-type = 'parallel-right-rtl'
									or @content-type = 'parallel-both-rtl'
									]/table-wrap">
		<table-wrap>
		  <!-- Unnötiger Test, wir wissen das ja schon -->
		  <!-- eventuell könnte man überlegen, ob das robuster sein soll, also andere werte noch mitnehmen? -->
		  <!-- <xsl:if test="starts-width(../@content-type, 'parallel')"> --> 
			<xsl:attribute name="content-type">
				<xsl:text>parallel</xsl:text>
			</xsl:attribute>
		  <!-- </xsl:if> -->
		  <xsl:copy-of select="@*|../@*[not(name() = 'content-type')]" />
		  <xsl:apply-templates />
		</table-wrap>
	</xsl:template>
	
	<xsl:template match="boxed-text[@content-type = 'parallel' 
									or @content-type = 'parallel-left-rtl'
									or @content-type = 'parallel-right-rtl'
									or @content-type = 'parallel-both-rtl'
									]/table-wrap/table">
	<table>
		<xsl:if test="../../@content-type = 'parallel-left-rtl'">
		  <xsl:attribute name="class">
			<xsl:text>left-rtl</xsl:text>
		  </xsl:attribute>
		</xsl:if>
		<xsl:if test="../../@content-type = 'parallel-right-rtl'">
		  <xsl:attribute name="content-type">
			<xsl:text>right-rtl</xsl:text>
		  </xsl:attribute>
		</xsl:if>
		<xsl:if test="../../@content-type = 'parallel-both-rtl'">
		  <xsl:attribute name="content-type">
			<xsl:text>left-rtl right-rtl</xsl:text>
		  </xsl:attribute>
		</xsl:if>
	<colgroup>
        <col>
		  <xsl:if test="../../@content-type = 'parallel-left-rtl' or ../../@content-type = 'parallel-both-rtl'">
		  <xsl:attribute name="style">
			<xsl:text>dir: rtl</xsl:text>
		  </xsl:attribute>
		  </xsl:if>
		</col>
        <col>
		<xsl:if test="../../@content-type = 'parallel-right-rtl' or ../../@content-type = 'parallel-both-rtl'">
		  <xsl:attribute name="style">
			<xsl:text>dir: rtl</xsl:text>
		  </xsl:attribute>
		  </xsl:if>
		</col> 						 
      </colgroup>
	<xsl:apply-templates />
	</table>
	</xsl:template>
	
	<xsl:template match="boxed-text[@content-type = 'parallel' 
									or @content-type = 'parallel-left-rtl'
									or @content-type = 'parallel-right-rtl'
									or @content-type = 'parallel-both-rtl'
									]">
		<xsl:apply-templates />
	</xsl:template>


<!-- RTL-Paragraphen -->
<xsl:template match="boxed-text[@content-type = 'righttoleft']">
	<xsl:apply-templates />
</xsl:template>

<xsl:template match="boxed-text[@content-type = 'righttoleft']/p">
	<p>
		<xsl:attribute name="content-type">
				<xsl:text>righttoleft</xsl:text>
		<xsl:copy-of select="@*" />
		</xsl:attribute>
		<xsl:apply-templates />
	</p>
</xsl:template>
</xsl:stylesheet>
