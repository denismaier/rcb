<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0" 
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:xlink="http://www.w3.org/1999/xlink" 
	xmlns:lang="http://www.w3.org/1999/xhtml"
	exclude-result-prefixes="xlink lang">

  <xsl:output method="html" indent="yes" version="5" html-version="5" encoding="UTF-8" />

<!--
 <xsl:preserve-space  elements="p"/>
 <xsl:strip-space elements="*"/>
-->

  <xsl:param name="stylesheet" />

  <xsl:template match="/">
    <html>
	  <xsl:attribute name="lang">
        <xsl:value-of select="/article/@xml:lang" />
	  </xsl:attribute>
      <head>
        <title>
          <xsl:value-of select="/article/front/article-meta/title-group/article-title" />
        </title>
        <xsl:if test="string($stylesheet)">
          <link rel="stylesheet" type="text/css" href="{$stylesheet}" media="screen" />
        </xsl:if>
      </head>
      <body>
        <xsl:apply-templates />
      </body>
    </html>
  </xsl:template>

  <xsl:template match="/article">
    <xsl:apply-templates />
  </xsl:template>

  <!-- toc -->

  <xsl:template name="heading-in-toc">
    <a>
      <xsl:attribute name="href">
        <xsl:text>#</xsl:text>
        <xsl:value-of select="@id" />
      </xsl:attribute>
      <xsl:if test="string(label)">
        <xsl:value-of select="label" />
        <xsl:text>&#x00A0;</xsl:text>
      </xsl:if>
      <xsl:apply-templates select="title" mode="toc" />
    </a>
  </xsl:template>
  
  <!-- Fussnoten-Links im TOC unterdrücken -->
  <xsl:template match="title" mode="toc">
    <xsl:apply-templates mode="toc" />
  </xsl:template>
  <xsl:template match="title/xref" mode="toc" />
  
  <!--
    Das hier ist möglicherweise zu kompliziert.
    man es sich sparen, wenn man jeweils den Titel bei der fn-group einträgt.
    oder man baut ein prä-prozessor xsl...
  -->
  <xsl:template name="fn-group-heading-in-toc">
    <a>
      <xsl:attribute name="href">
        <xsl:text>#</xsl:text>
        <xsl:text>id-fn-group</xsl:text>
      </xsl:attribute>
      <xsl:if test="string(label)">
        <xsl:value-of select="label" />
        <xsl:text>&#x00A0;</xsl:text>
      </xsl:if>
       <xsl:if test="/article/@xml:lang='en'">
        <xsl:text>Notes</xsl:text>
      </xsl:if>
      <xsl:if test="/article/@xml:lang='de'">
        <xsl:text>Anmerkungen</xsl:text>
      </xsl:if>
    </a>
  </xsl:template>

  <xsl:template name="app-heading-in-toc">
    <a>
      <xsl:attribute name="href">
        <xsl:text>#</xsl:text>
        <xsl:value-of select="@id" />
      </xsl:attribute>
      <xsl:if test="string(label)">
        <xsl:value-of select="label" />
        <xsl:text>&#x00A0;</xsl:text>
      </xsl:if>
      <xsl:apply-templates select="title" mode="toc" />
    </a>
    <br />
    <xsl:for-each select="//sec[not(@sec-type = 'thought-break-asterism')][ancestor::app]">
      <xsl:call-template name="heading-in-toc" />
      <br />
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="toc-div">
    <xsl:if test="string(/article/body/sec[1]) or string(//fn-group) or string(//ref-list)">
    <div class="toc">
      <h3>
        <xsl:if test="/article/@xml:lang='en'">
          Contents
        </xsl:if>
        <xsl:if test="/article/@xml:lang='de'">
          Inhalt
        </xsl:if>
      </h3>
      <xsl:for-each select="//sec[not(@sec-type = 'thought-break-asterism')][not(ancestor::back)]">
        <xsl:call-template name="heading-in-toc"/>
        <br/>
      </xsl:for-each>
      <xsl:for-each select="//fn-group">
        <xsl:call-template name="fn-group-heading-in-toc"/>
        <br/>
      </xsl:for-each>
      <xsl:for-each select="//back/app-group/app">
      <xsl:call-template name="app-heading-in-toc"/>
    </xsl:for-each>
      <xsl:for-each select="//ref-list">
        <xsl:call-template name="heading-in-toc"/>
        <br/>
      </xsl:for-each>
    </div>
    </xsl:if>
  </xsl:template>


  <!-- front -->


  <xsl:template match="/article/front">
    <div class="frontmatter">
    <div class="main">
    <h1 class="article-title">
      <xsl:apply-templates select="article-meta/title-group/article-title"/>
    </h1>
    <xsl:if test="article-meta/title-group/subtitle">
      <p class="subtitle">
        <xsl:apply-templates select="article-meta/title-group/subtitle/node()"/>
      </p>
    </xsl:if>
        <!-- Damit kann man die Auswahl einschränken -->
        <!-- <xsl:for-each select="article-meta/contrib-group[not(string(@content-type))]/contrib">  -->
	<div class="contributors">
		<xsl:for-each select="article-meta/contrib-group/contrib">
		  <div class="contributor">
		  <span class="author-name">
			<xsl:value-of select="name/given-names"/>
			<xsl:text>&#x00A0;</xsl:text>
			<xsl:value-of select="name/surname"/>
			<xsl:text>&#x00A0;</xsl:text>
			<xsl:if test="string(role)">
			  (<xsl:value-of select="role"/>)
			</xsl:if>
		  </span>
		  <xsl:if test="string(aff)">
			  <br/>
			  <span class="affiliation">
				<xsl:value-of select="aff"/>
			  </span>
		  </xsl:if>
		  <xsl:if test="string(email)">
		  <br/>
			  <span class="author-email">
				<a>
				  <xsl:attribute name="href">
					<xsl:text>mailto:</xsl:text>
					<xsl:value-of select="email"/>
				  </xsl:attribute>
				  <xsl:value-of select="email"/>
				</a>
			  </span>
		  </xsl:if>
		  </div>
		</xsl:for-each>
	</div>
    <div class="metadata">
      <xsl:value-of select="journal-meta/journal-title-group/journal-title"/>
          <!-- <xsl:text>&#x00A0;Jg.&#x00A0;</xsl:text> -->
      <xsl:text>&#160;</xsl:text>
      <xsl:value-of select="article-meta/volume"/>
	  <xsl:if test="string(article-meta/issue)">
		<xsl:if test="/article/@xml:lang='en'">
          <xsl:text>, no.&#160;</xsl:text>
        </xsl:if>
        <xsl:if test="/article/@xml:lang='de'">
          <xsl:text>, Nr.&#160;</xsl:text>
        </xsl:if>
		<xsl:value-of select="article-meta/issue"/>
	  </xsl:if>
      <xsl:text> (</xsl:text>
      <xsl:value-of select="article-meta/pub-date/year"/>
      <xsl:text>)</xsl:text>
      <br/>
          <!--        <xsl:value-of select="journal-meta/issn"/><xsl:text>.&#x00A0;</xsl:text>-->
          <!--        <xsl:value-of select="journal-meta/publisher/publisher-loc"/>-->
          <!--         <xsl:text>:&#x00A0;</xsl:text>-->
          <!--        <xsl:value-of select="journal-meta/publisher/publisher-name"/>-->
      <a>
        <xsl:attribute name="href">
          <xsl:value-of select="article-meta/article-id"/>
        </xsl:attribute>
        <xsl:value-of select="article-meta/article-id"/>
      </a>
      <br/>
      <a rel="license" href="https://creativecommons.org/licenses/by/4.0/">CC BY 4.0 International
        License</a>
      <br/>
    </div>
    </div>
    <div class="abstract-and-toc">
    <div class="main"><xsl:if test="string(article-meta/abstract)">
      <div class="abstract">
        <h3>
          <xsl:text>Abstract</xsl:text>
        </h3>
        <xsl:apply-templates select="article-meta/abstract"/>
      </div>
    </xsl:if></div>
    <xsl:call-template name="toc-div"/>
    </div>
    </div>
  </xsl:template>

  <!-- end front -->
  <!-- body -->

  <xsl:template match="/article/body">
    <div class="main">
    <xsl:apply-templates/>
    </div>
  </xsl:template>

  <!-- regular headings -->
  <xsl:template match="/article/body/sec">
    <h2>
      <xsl:attribute name="id">
        <xsl:value-of select="@id"/>
      </xsl:attribute>
      <xsl:if test="string(label)">
        <xsl:value-of select="label"/>
        <xsl:text>&#x00A0;</xsl:text>
      </xsl:if>
      <xsl:apply-templates select="title" mode="process"/>
    </h2>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="/article/body/sec/label"/>
  <xsl:template match="/article/body/sec/title"/>
  <!-- only process when called via the /article/body/sec template, not standalone-->
  <xsl:template match="/article/body/sec/title" mode="process">
	<xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="/article/body/sec/sec">
    <h3>
      <xsl:attribute name="id">
        <xsl:value-of select="@id"/>
      </xsl:attribute>
      <xsl:if test="string(label)">
        <xsl:value-of select="label"/>
        <xsl:text>&#x00A0;</xsl:text>
      </xsl:if>
      <xsl:value-of select="title"/>
    </h3>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="/article/body/sec/sec/label"/>
  <xsl:template match="/article/body/sec/sec/title"/>

  <xsl:template match="/article/body/sec/sec/sec">
    <h4>
      <xsl:attribute name="id">
        <xsl:value-of select="@id"/>
      </xsl:attribute>
      <xsl:if test="string(label)">
        <xsl:value-of select="label"/>
        <xsl:text>&#x00A0;</xsl:text>
      </xsl:if>
      <xsl:value-of select="title"/>
    </h4>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="/article/body/sec/sec/sec/label"/>
  <xsl:template match="/article/body/sec/sec/sec/title"/>

  <!-- thought breaks -->
  <xsl:template match="sec[@sec-type='thought-break-asterism']">
	<p class="thought-break-asterism">*</p>
	<xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="sec[@sec-type='thought-break']">
  <p class="thought-break"/>
  <xsl:apply-templates/>
  </xsl:template>

  <!-- links -->
  <xsl:template match="//xref">
    <xsl:if test="@ref-type = 'bibr'">
      <a class="xref-bibr">
        <xsl:attribute name="href">
          <xsl:text>#</xsl:text>
          <xsl:value-of select="@rid"/>
        </xsl:attribute>
        <xsl:value-of select="."/>
      </a>
    </xsl:if>
    <xsl:if test="@ref-type = 'fig'">
      <a class="xref-bibr">
        <xsl:attribute name="href">
          <xsl:text>#</xsl:text>
          <xsl:value-of select="@rid"/>
        </xsl:attribute>
        <xsl:value-of select="."/>
      </a>
    </xsl:if>
    <xsl:if test="@ref-type = 'table'">
      <a class="xref-bibr">
        <xsl:attribute name="href">
          <xsl:text>#</xsl:text>
          <xsl:value-of select="@rid"/>
        </xsl:attribute>
        <xsl:value-of select="."/>
      </a>
    </xsl:if>
    <xsl:if test="@ref-type = 'fn'">
      <sup>
        <a class="xref-bibr">
          <xsl:attribute name="href">
            <xsl:text>#</xsl:text>
            <xsl:value-of select="@rid"/>
          </xsl:attribute>
          <xsl:attribute name="id">
            <xsl:text>r</xsl:text>
            <xsl:value-of select="@rid"/>
          </xsl:attribute>
          <xsl:value-of select="."/>
        </a>
      </sup>
    </xsl:if>
  </xsl:template>


  <!-- 
	TODO: Sort this out
	Wir brauchen entweder die eine oder die andere Variante
-->

  <!--
  <xsl:template match="//named-content">
    <xsl:if test="@content-type = 'rtl'">
      <span>
        <xsl:attribute name="align">
          <xsl:text>right</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="dir">
          <xsl:text>rtl</xsl:text>
        </xsl:attribute>
        <xsl:apply-templates/>
      </span>
    </xsl:if>
  </xsl:template>
 -->

  <!-- Named-content -> Span
	Für den Moment ok, aber die Attribute funktionieren so nicht.
	Da wir das aber eh nur für die Sprachumschaltung brauchen, ist es egal.

	
  <xsl:template match="//named-content">
    <span>
      <xsl:apply-templates select="@* | node()"/>
    </span>
  </xsl:template>
  
  <xsl:template match="@xml:lang">
   <xsl:attribute name="xml:lang">
      <xsl:value-of select="."/>
   </xsl:attribute>
</xsl:template>


  <xsl:template match="//named-content">
    <span>
       <xsl:copy-of select="@*"/>
       <xsl:apply-templates/>
    </span>
  </xsl:template>
  -->
  
   <xsl:template match="//named-content">
    <span>
      <xsl:apply-templates select="@*|node()"/>
    </span>
  </xsl:template>
  
  <xsl:template match="//named-content[@content-type='bdoltr']">
    <bdo dir="ltr">
      <xsl:apply-templates select="@*|node()"/>
    </bdo>
  </xsl:template>
  
  <xsl:template match="//named-content[@content-type='bdortl']">
    <bdo dir="rtl">
      <xsl:apply-templates select="@*|node()"/>
    </bdo>
  </xsl:template>
  
  <xsl:template match="//named-content/@content-type">
   <xsl:attribute name="class">
	   <xsl:value-of select="."/>
   </xsl:attribute>
  </xsl:template>
  
  <xsl:template match="//named-content/@xml:lang">
    <xsl:attribute name="lang">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="//styled-content">
    <span>
      <xsl:apply-templates select="@*|node()"/>
    </span>
  </xsl:template> 
  
  <xsl:template match="//styled-content/@xml:lang">
    <xsl:attribute name="lang">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>
  
  <xsl:template match="//styled-content/@style">
    <xsl:attribute name="style">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>


  <!-- <xsl:template match="//disp-quote"> -->
  <!-- <blockquote> -->
  <!-- <xsl:apply-templates/> -->
  <!-- </blockquote> -->
  <!-- </xsl:template> -->

  <!-- <xsl:template match="//disp-quote">  -->
  <!-- <xsl:copy>  -->
  <!-- <xsl:apply-templates select="@*|node()" />  -->
  <!-- </xsl:copy>  -->
  <!-- </xsl:template> -->

  <xsl:template match="//disp-quote">
    <blockquote>
	  <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
    </blockquote>
  </xsl:template>
  
    <xsl:template match="//preformat">
    <pre class="epigraph">
	  <xsl:apply-templates/>
    </pre>
  </xsl:template>
  <!-- <xsl:apply-templates select="translate(., '	', '')" /> -->

  
  
  <xsl:template match="//attrib">
      <p class="attrib">
	  <xsl:apply-templates/>
	  </p>
  </xsl:template>
  
  
  
  
  <xsl:template match="@style[.='dir: rtl']">
   <xsl:attribute name="dir">
     <xsl:text>rtl</xsl:text>
   </xsl:attribute>
</xsl:template>

  <!-- <xsl:template match="//disp-quote[@style='dir: rtl']"> -->
  <!-- <blockquote style="direction: rtl'"> -->
  <!-- <xsl:apply-templates/> -->
  <!-- </blockquote> -->
  <!-- </xsl:template> -->

  <xsl:template match="//table-wrap">
    <div align="center">
	<xsl:choose>
		<xsl:when test="string(@content-type)">
		  <xsl:attribute name="class">
			<xsl:value-of select="@content-type"/>
		  </xsl:attribute>
		</xsl:when>
		<xsl:otherwise>
			<xsl:attribute name="class">
				<xsl:text>table-wrap</xsl:text>
			  </xsl:attribute>
		</xsl:otherwise>
	</xsl:choose>
	<xsl:if test="string(@id)">
      <xsl:attribute name="id">
        <xsl:value-of select="@id"/>
      </xsl:attribute>
	</xsl:if>
     <xsl:if test="string(caption)">
        <p class="table_caption">
          <xsl:if test="string(label)">
            <xsl:value-of select="label"/>
            <xsl:text>:&#x00A0;</xsl:text>
          </xsl:if>
          <xsl:apply-templates select="caption/p/node()"/>
        </p>
      </xsl:if>
      <xsl:apply-templates select="table"/>
    </div>
  </xsl:template>

  <xsl:template match="//table-wrap/caption"/>
  <xsl:template match="//table-wrap/label"/>


  <xsl:template match="//table">
    <table>
	 <xsl:if test="string(@content-type)">
      <xsl:attribute name="class">
        <xsl:value-of select="@content-type"/>
      </xsl:attribute>
	  </xsl:if>
      <xsl:apply-templates/>
    </table>
  </xsl:template>
  
  <xsl:template match="//table/colgroup"/>
  
  <xsl:template match="//thead">
    <thead>
      <xsl:apply-templates/>
    </thead>
  </xsl:template>

  <xsl:template match="//tbody">
    <tbody>
      <xsl:apply-templates/>
    </tbody>
  </xsl:template>

  <xsl:template match="//tr">
    <tr>
      <xsl:apply-templates/>
    </tr>
  </xsl:template>

  <xsl:template match="//th">
    <th>
      <!-- todo: make this more general -->
	  <xsl:attribute name="align">
        <xsl:value-of select="@align"/>
      </xsl:attribute>
      <xsl:apply-templates/>
    </th>
  </xsl:template>

    <xsl:template match="//td">
    <td>
      <xsl:apply-templates/>
    </td>
  </xsl:template>
  
  <xsl:template match="fig-group">
    <div class="fig-group">
	<div class="row">
      <xsl:apply-templates/>
	</div>
	  <xsl:if test="string(caption)">
      <p class="pic_caption">
        <xsl:if test="string(label)">
          <span class="pic_caption_label"><xsl:value-of select="label"/></span>
          <xsl:text>:&#x00A0;</xsl:text>
        </xsl:if>
        <span class="pic_caption_text"><xsl:apply-templates select="caption/p/node()"/></span>
      </p>
    </xsl:if>
	</div>
  </xsl:template>
  
  <xsl:template match="fig-group/label"/>
  <xsl:template match="fig-group/caption"/>


  <xsl:template match="//fig">
    <figure>
    <img>
      <xsl:attribute name="src">
        <xsl:value-of select="graphic/@xlink:href"/>
      </xsl:attribute>
      <xsl:attribute name="id">
        <xsl:value-of select="@id"/>
      </xsl:attribute>
    </img>
    <xsl:if test="string(caption)">
      <p class="pic_caption">
        <xsl:if test="string(label)">
          <span class="pic_caption_label"><xsl:value-of select="label"/></span>
          <xsl:text>:&#x00A0;</xsl:text>
        </xsl:if>
        <span class="pic_caption_text"><xsl:apply-templates select="caption/p/node()"/></span>
      </p>
    </xsl:if>
	</figure>
  </xsl:template>

  <xsl:template match="//ext-link">
    <a>
      <xsl:attribute name="href">
        <xsl:value-of select="@xlink:href"/>
      </xsl:attribute>
      <xsl:value-of select="."/>
    </a>
  </xsl:template>

  <xsl:template match="//italic">
    <i>
      <xsl:apply-templates/>
    </i>
  </xsl:template>

  <xsl:template match="//bold">
    <b>
      <xsl:apply-templates/>
    </b>
  </xsl:template>
  
  <xsl:template match="//sc">
    <span class="smallcaps">
      <xsl:apply-templates/>
    </span>
  </xsl:template>

  <xsl:template match="//strike">
    <del>
      <xsl:apply-templates/>
    </del>
  </xsl:template>

  <xsl:template match="//underline">
    <u>
      <xsl:apply-templates/>
    </u>
  </xsl:template>
  
  <xsl:template match="//sup">
    <sup>
      <xsl:apply-templates/>
    </sup>
  </xsl:template>

  <xsl:template match="//list[@list-type = 'order']">
    <ol>
      <xsl:apply-templates/>
    </ol>
  </xsl:template>
  
   <xsl:template match="//list[@list-type = 'alpha-lower']">
    <ol type="a">
      <xsl:apply-templates/>
    </ol>
  </xsl:template>
  
  <xsl:template match="//list[@list-type = 'alpha-upper']">
    <ol type="A">
      <xsl:apply-templates/>
    </ol>
  </xsl:template>

  <xsl:template match="//list[@list-type = 'bullet']">
    <ul>
      <xsl:apply-templates/>
    </ul>
  </xsl:template>

  <!-- DEFINITION LISTS -->
  <!-- <dl>  -->
  <!-- <dt>PHP</dt> -->
  <!-- <dd>A server side scripting language.</dd>  -->
  <!-- <dt>JavaScript</dt> -->
  <!-- <dd>A client side scripting language.</dd>  -->
  <!-- </dl> -->
	
  <xsl:template match="//def-list">
    <dl>
      <xsl:apply-templates/>
    </dl>
  </xsl:template>
  
  <xsl:template match="//def-list/def-item">
     <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="//def-list/def-item/term">
     <dt><xsl:apply-templates/></dt>
  </xsl:template>
  
  <xsl:template match="//def-list/def-item/def">
     <dd><xsl:apply-templates/></dd>
  </xsl:template>

  <!-- \xmlsetsetup{#1}{def-list}{xml:*} -->
  <!-- \xmlsetsetup{#1}{def-list/title}{xml:def-list:title} -->
  <!-- \xmlsetsetup{#1}{def-list/term-head}{xml:def-list:term-head} -->
  <!-- \xmlsetsetup{#1}{def-list/def-head}{xml:def-list:def-head} -->
  <!-- \xmlsetsetup{#1}{def-list/def-item}{xml:def-list:def-item} -->
  <!-- \xmlsetsetup{#1}{def-list/def-item/term}{xml:def-list:def-item:term} -->
  <!-- \xmlsetsetup{#1}{def-list/def-item/def}{xml:def-list:def-item:def} -->

  <!-- VERSE-GROUPS -->

  <xsl:template match="//verse-group[@content-type='verse-group-wrapper']">
    <div class="verse-material">
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="//verse-group[@content-type='verse-group-wrapper-centered']">
    <div class="verse-material-centered">
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="//verse-group[@content-type='stanza']">
    <p class="stanza">
      <xsl:apply-templates/>
    </p>
  </xsl:template>
  
  <xsl:template match="verse-group[@content-type='stanza']/verse-line">
    <xsl:apply-templates/><br/><xsl:text>&#xa;</xsl:text>
  </xsl:template>
  
  <xsl:template match="//verse-group[@content-type='stanza']/attrib">
  <span class="attrib"><xsl:apply-templates/></span>
  </xsl:template>


  <!-- BOXED-TEXT -->
  
  <xsl:template match="//boxed-text">
    <div>
      <xsl:attribute name="content-type">
        <xsl:value-of select="@content-type"/>
      </xsl:attribute>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <!-- Das hier wäre einfacher
    Dafür muss man aber die Identity Transformation weiter unten aktivieren...
  <xsl:template match="boxed-text">
    <div>
      <xsl:apply-templates select="@* | node()"/>
    </div>
  </xsl:template>
  -->

  <xsl:template match="//p">
    <p>
	<!-- <xsl:if test="string(@content-type)"> -->
	  <!-- <xsl:attribute name="content-type"> -->
        <!-- <xsl:value-of select="@content-type"/> -->
      <!-- </xsl:attribute> -->
	  <!-- </xsl:if> -->
	  <xsl:if test="@content-type='righttoleft'">
        <xsl:attribute name="style">
        <xsl:text>direction: rtl; text-align: right;</xsl:text>
      </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates/>
    </p>
  </xsl:template>

  <xsl:template match="//list-item">
    <li>
      <xsl:apply-templates/>
    </li>
  </xsl:template>

  <!-- end body -->
  <!-- back -->

  <xsl:template match="/article/back">
        <div class="main">
          <xsl:apply-templates/>
        </div>
  </xsl:template>

  <xsl:template match="/article/back/app-group">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="/article/back/app-group/app">
  <h2>
    <xsl:attribute name="id">
      <xsl:value-of select="@id"/>
    </xsl:attribute>
    <xsl:value-of select="title"/>
  </h2>
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="/article/back/app-group/app/title"/>

<xsl:template match="/article/back/app-group/app/sec">
<h3>
  <xsl:attribute name="id">
    <xsl:value-of select="@id"/>
  </xsl:attribute>
  <xsl:value-of select="title"/>
</h3>
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="/article/back/app-group/app/sec/title"/>


  <xsl:template match="/article/back/fn-group">
    <h2>
      <xsl:attribute name="id">
        <xsl:text>id-fn-group</xsl:text>
      </xsl:attribute>
      <xsl:if test="/article/@xml:lang='en'">
        Notes
      </xsl:if>
      <xsl:if test="/article/@xml:lang='de'">
        Anmerkungen
      </xsl:if>
    </h2>
    <div class="article-meta-notes">
      <xsl:apply-templates select="/article/front/notes"/>
    </div>
    <ol class="fn-group">
      <xsl:apply-templates/>
    </ol>
  </xsl:template>

  <xsl:template match="/article/back/fn-group/title"/>

  <xsl:template match="/article/back/fn-group/fn">
    <li class="fn">
      <xsl:attribute name="id">
        <xsl:value-of select="@id"/>
      </xsl:attribute>
      <xsl:apply-templates/>
    </li>
  </xsl:template>
  
  <xsl:template match="/article/back/fn-group/fn/p[last()]" priority="1">
    <p>
	  <!-- <xsl:if test="string(@content-type)"> -->
	  <!-- <xsl:attribute name="content-type"> -->
        <!-- <xsl:value-of select="@content-type"/> -->
      <!-- </xsl:attribute> -->
	  <!-- </xsl:if> -->
	  <xsl:if test="@content-type='righttoleft'">
        <xsl:attribute name="style">
        <xsl:text>direction: rtl; text-align: right;</xsl:text>
      </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates/>
      <a class="fn-back">
        <xsl:attribute name="href">
          <xsl:text>#r</xsl:text>
          <xsl:value-of select="../@id"/>
        </xsl:attribute>&#11025;</a>
    </p>
  </xsl:template>

  <xsl:template match="/article/back/ref-list">
    <h2>
      <xsl:attribute name="id">
        <xsl:value-of select="@id"/>
      </xsl:attribute>
      <xsl:value-of select="/article/back/ref-list/title"/>
    </h2>
    <div class="ref-list">
      <xsl:apply-templates/>
    </div>
  </xsl:template>


  <!-- Subdivided bibliographies -->
  <!-- Ugly, but ok for the time being ... -->
  <xsl:template match="/article/back/ref-list/ref-list">
    <h3>
      <xsl:attribute name="id">
        <xsl:value-of select="@id"/>
      </xsl:attribute>
      <xsl:value-of select="title"/>
    </h3>
    <div class="ref-list">
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="//ref-list/ref">
      <xsl:apply-templates/>
  </xsl:template>

<xsl:template match="//ref-list/ref/mixed-citation">
   <p>
	<xsl:apply-templates/>
   </p>
   </xsl:template>

  <xsl:template match="/article/back/ref-list/title"/>
  <xsl:template match="/article/back/ref-list/ref-list/title"/>

  <xsl:template match="/article/back/fn-group/fn/@id"/>

  <!-- List of shorthands -->
  <!-- Ugly, but ok for the time being ... -->
  <xsl:template match="/article/back/ref-list/ref-list[@content-type='shorthands']">
    <h3>
      <xsl:attribute name="id">
        <xsl:value-of select="@id"/>
      </xsl:attribute>
      <xsl:value-of select="title"/>
    </h3>
    <div class="ref-list-shorthands">
	  <table>
        <xsl:apply-templates/>
	  </table>
    </div>
  </xsl:template>
  
  <xsl:template match="//ref-list[@content-type='shorthands']/ref">
    <tr>
      <xsl:apply-templates/>
	</tr>
  </xsl:template>

<xsl:template match="//ref-list[@content-type='shorthands']/ref/label">
   <td>
	<xsl:apply-templates/>
   </td>
   </xsl:template>
<xsl:template match="//ref-list[@content-type='shorthands']/ref/mixed-citation">
   <td>
	<xsl:apply-templates/>
   </td>
   </xsl:template>


  <!-- end back -->

  <!--
<xsl:template match="@*|node()">










  </xsl:template>
  -->

</xsl:stylesheet>
