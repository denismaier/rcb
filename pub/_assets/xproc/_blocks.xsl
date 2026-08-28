<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                exclude-result-prefixes="xsl">

  <!--
    Bloecke: disp-quote-Varianten (blockquotenoindenting, rtlblockquote),
    epigraph, preformat, attrib, VERSE (verse, verse-centered, verse-line
    + attrib) und parallel-verse. Extrahiert aus cleanup.xsl (Phase 20a).
    Eigener p:xslt-Step in cleanup.xpl nach _tables, VOR (frueher) cleanup.xsl.

    Two-Pass-Sicherheit: boxed-text wird auch von _tables gematcht, aber
    ueber disjunkte content-types (hier: blockquote/epigraph/preformat/
    attrib/verse/parallel-verse vs. labeled/float/parallel*/righttoleft
    in _tables). parallel-verse baut table-wrap[@content-type='parallel']
    inside boxed-text[@content-type='parallel-verse'] — _tables matcht nur
    boxed-text[@content-type='parallel']/table-wrap (exaktes Prädikat),
    greift also NICHT auf parallel-verse-Output zu. Da _tables VOR _blocks
    laeuft, ist parallel-verse bei _tables noch intakt. Keine Kollision.
    xsl:output kosmetisch, Serialisierung regiert cleanup.xpl p:output.
  -->
  <xsl:output method="xml" indent="yes"/>
  <xsl:mode on-no-match="shallow-copy"/>
<!-- Blockquotes ohne Erstzeileneinzug) -->

<xsl:template match="boxed-text[@content-type = 'blockquotenoindenting']">
	<xsl:apply-templates />
</xsl:template>


<xsl:template match="boxed-text[@content-type = 'blockquotenoindenting']/disp-quote">
    <disp-quote content-type="blockquotenoindenting">
	<xsl:apply-templates />
	</disp-quote>
</xsl:template>



	
<!-- RTL-Blockquotes -->
<xsl:template match="boxed-text[@content-type = 'rtlblockquote']">
	<xsl:apply-templates />
</xsl:template>

<xsl:template match="boxed-text[@content-type = 'rtlblockquote']/disp-quote">
	<disp-quote>
		<xsl:attribute name="style">
				<xsl:text>direction: rtl</xsl:text>
		<xsl:copy-of select="@*" />
		</xsl:attribute>
		<xsl:apply-templates />
	</disp-quote>
</xsl:template>

<!-- Epigraphs -->
	<xsl:template match="boxed-text[@content-type = 'epigraph']">
	<disp-quote>
		<xsl:copy-of select="@*"/>
        <xsl:apply-templates/>
	</disp-quote>
	</xsl:template>
	
	<xsl:template match="boxed-text[@content-type = 'preformat']">
        <xsl:apply-templates/>
	</xsl:template>
	
	<xsl:template match="boxed-text[@content-type = 'preformat']/p">
	<preformat>
        <xsl:apply-templates/>
	</preformat>
	</xsl:template>
	
	<xsl:template match="boxed-text[@content-type = 'attrib']">
        <xsl:apply-templates/>
	</xsl:template>
	
	<xsl:template match="boxed-text[@content-type = 'attrib']/p">
	<attrib>
        <xsl:apply-templates/>
	</attrib>
	</xsl:template>
	


<!-- VERSE -->
	<xsl:template match="boxed-text[@content-type = 'verse']">
		<verse-group content-type="verse-group-wrapper">
			<xsl:apply-templates />
		</verse-group>
	</xsl:template>
	
	<xsl:template match="boxed-text[@content-type = 'verse-centered']">
		<verse-group content-type="verse-group-wrapper-centered">
			<xsl:apply-templates />
		</verse-group>
	</xsl:template>
	
	<xsl:template match="boxed-text[@content-type = 'verse' or @content-type = 'verse-centered']/p">
		<verse-group content-type="stanza">
		  <xsl:apply-templates />
		</verse-group>
	</xsl:template>
	
	<xsl:template match="named-content[@content-type = 'verse-line']">
	  <verse-line><xsl:apply-templates /></verse-line>
	</xsl:template>
	
	<xsl:template match="named-content[@content-type = 'verse-line' and named-content[@content-type = 'attrib']]">
	<attrib>
        <xsl:apply-templates/>
	</attrib>
	</xsl:template>
	
	<xsl:template match="named-content[@content-type = 'verse-line']/ named-content[@content-type = 'attrib']">
        <xsl:apply-templates/>
	</xsl:template>
	
	<!-- <xsl:template match="boxed-text[@content-type = 'verse-group']/p[*[2]]"> -->
	<!-- <verse-group> -->
	<!-- <xsl:apply-templates /> -->
	<!-- </verse-group> -->
	<!-- </xsl:template> -->

<!-- PARAVERSESUPPORT -->
<xsl:template match="boxed-text[@content-type = 'parallel-verse']">
  <boxed-text content-type="parallel-verse">
	<table-wrap content-type="parallel">
         <table>
            <tbody>
               <tr>
                  <xsl:apply-templates />
               </tr>
            </tbody>
         </table>
      </table-wrap>
  </boxed-text>
</xsl:template>

<xsl:template match="boxed-text[@content-type = 'parallel-verse']/boxed-text[@content-type = 'verse']">
	<td>
		<verse-group content-type="verse-group-wrapper">
			<xsl:apply-templates />
		</verse-group>
	</td>
</xsl:template>

<xsl:template match="boxed-text[@content-type = 'parallel-verse']/boxed-text[@content-type = 'verse-centered']">
	<td>
		<verse-group content-type="verse-group-wrapper-centered">
			<xsl:apply-templates />
		</verse-group>
	</td>
</xsl:template>
</xsl:stylesheet>
