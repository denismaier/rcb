<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                version="3.0"
                name="cleanup">

  <p:input port="source"/>
  <p:output port="result" serialization="map{'indent': true()}"/>


  <p:identity message="Cleanup Pipeline is running -- passing document"/>

</p:declare-step>
