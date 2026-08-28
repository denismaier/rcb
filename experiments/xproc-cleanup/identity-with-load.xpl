<?xml version="1.0" encoding="UTF-8"?>
<!--
  Identity-Pipeline mit *explizitem* <p:load> statt source-Port.

  Zweck: DTD-Default-Expansion kontrolliert *ausschalten* via
  mox:expand-default-attributes = false() in der parameters-Map.

  Semantik (Achim Berndzen, 2026-06-25; empirisch verifiziert):
    - Wörtliche Lesart des Namens: true = Defaults expandieren
      (Default-Wert ist true), false = suppress.
    - Option greift NUR, wenn dtd-validate = false (Default)
      UND mox:ignore-external-dtd = false (Default) — beides erfüllt.
    - Der Doku-Satz "if the associated value is true, no attempt is
      made to expand" ist ein Dokumentationsfehler (invertiert);
      empirisch + laut Achims letztem Satz ("default true → expanded")
      gilt true = expandieren. Auf false() setzen.
    - Verifiziert 2026-06-25: false() entfernt dtd-version + @position
      auf boxed-text; boxed-text-Wrapper überlebt. xmlns:*-Namespace-
      Defaults bleiben (andere XML-Mechanik, nicht ATTLIST).

  Calabash kennt die mox:-Keys nicht (unbekannte QName-Keys in der Map);
  Calabash-Suppress-Mechanik noch offen (xproc-dev-Liste). Siehe
  Roadmap Phase 20c + Decision Log 2026-06-25 (weiter mit Morgana).

  href ist vorerst hardcoded; CLI-Option-Syntax fuer Calabash steht
  noch aus.
-->
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:mox="http://www.xml-project.com/morganaxproc"
                version="3.0">

  <p:output port="result" serialization="map{'indent': true()}"/>

  <p:load href="inputs/04-boxed-text-jats.xml">
    <p:with-option name="parameters" select="map{
      xs:QName('mox:expand-default-attributes'): false()
    }"/>
  </p:load>

  <p:identity/>

</p:declare-step>
