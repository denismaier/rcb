@echo off
REM Sandbox-Test-Runner.
REM   .\tests                            -> alle Tests
REM   .\tests 01-minimal                 -> exakter Name (oder Substring)
REM   .\tests 02-                        -> Substring-Match: alle "02-*"
REM   .\tests 02-* section               -> mehrere Filter (alle Treffer)
REM
REM Filter = Substring gegen die Liste in TESTS. Stern wird zu '' gestript.
REM Test-Definitionen sind die :labels weiter unten.
REM Neuer Test: in TESTS eintragen + :label unten anlegen.

setlocal enabledelayedexpansion
cd /d "%~dp0"
if not exist "out" mkdir out
del /Q out\*.xml 2>nul

REM JATS-Catalog (relativ zur Sandbox); zeigt auf die Production-Kopie unter pub/_assets/jats-dtd/
set "CATALOG=../../pub/_assets/jats-dtd/catalog-jats-v1-2-no-base.xml"

REM Absolute Inputs-Dir als file://-URI (Forward-Slashes). <p:load href> im
REM .xpl loest den Wert als URI auf (relativ zur .xpl-Base-URI) — die .xpl
REM liegt jetzt in Production (pub/_assets/xproc/), also wuerde ein
REM relatives 'inputs/..' dort gesucht; ein raw-OS-Pfad gilt als URI ohne
REM Host. Daher file://-URI gegen die Sandbox-Inputs. (expected/out/catalog
REM bleiben relativ zur Sandbox-cwd.)
set "INPUTS_DIR=file:///%~dp0inputs"
set "INPUTS_DIR=!INPUTS_DIR:\=/!"

set "TESTS=00-pi-survival 01-minimal 02-section-numbering 02-section-numbering-nonum 03-doctype-baseline 04-boxed-text-jats 04-load-morgana 05-back-moves 06-figures 07-tables 08-parallel 09-blocks 10-verse 11-strips 12-anchor-default"

set /a PASSED=0
set /a FAILED=0

if "%~1"=="" goto :run_all

:next_arg
if "%~1"=="" goto :report

set "FILTER=%~1"
if "!FILTER:~0,1!"=="*" set "FILTER=!FILTER:~1!"
if "!FILTER:~-1!"=="*" set "FILTER=!FILTER:~0,-1!"

set MATCHED=0
for %%t in (%TESTS%) do (
  echo %%t | findstr /c:"!FILTER!" >nul
  if !errorlevel! equ 0 (
    call :%%t
    if !errorlevel! equ 0 (set /a PASSED+=1) else (set /a FAILED+=1)
    set MATCHED=1
  )
)

if !MATCHED! equ 0 echo Warning: no tests matched filter "!FILTER!"

shift
goto :next_arg

:run_all
for %%t in (%TESTS%) do (
  call :%%t
  if !errorlevel! equ 0 (set /a PASSED+=1) else (set /a FAILED+=1)
)
goto :report

:report
echo.
echo === Summary: !PASSED! passed, !FAILED! failed ===
goto :eof

REM ============================================================
REM Test definitions
REM ============================================================

:01-minimal
echo.
echo === Test: 01-minimal ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/01-minimal.xml' ^
  -output:result=out/01-minimal.xml
fc /b expected\01-minimal.xml out\01-minimal.xml
exit /b

:02-section-numbering
echo.
echo === Test: 02-section-numbering ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/02-section-numbering.xml' ^
  -output:result=out/02-section-numbering.xml
fc /b expected\02-section-numbering.xml out\02-section-numbering.xml
exit /b

:02-section-numbering-nonum
echo.
echo === Test: 02-section-numbering with nonumheadings=true ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/02-section-numbering.xml' ^
  -output:result=out/02-section-numbering--nonumheadings.xml ^
  -option:nonumheadings='true'
fc /b expected\02-section-numbering--nonumheadings.xml out\02-section-numbering--nonumheadings.xml
exit /b

:03-doctype-baseline
echo.
echo === Test: 03-doctype-baseline ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/03-doctype-baseline.xml' ^
  -output:result=out/03-doctype-baseline.xml
fc /b expected\03-doctype-baseline.xml out\03-doctype-baseline.xml
exit /b

:04-boxed-text-jats
echo.
echo === Test: 04-boxed-text-jats (external JATS DTD via catalog) ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -catalogs=%CATALOG% ^
  -option:source-href='!INPUTS_DIR!/04-boxed-text-jats.xml' ^
  -output:result=out/04-boxed-text-jats.xml
fc /b expected\04-boxed-text-jats.xml out\04-boxed-text-jats.xml
exit /b
:05-back-moves
echo.
echo === Test: 05-back-moves (ref-list + appendix moved to back) ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/05-back-moves.xml' ^
  -output:result=out/05-back-moves.xml
fc /b expected\05-back-moves.xml out\05-back-moves.xml
exit /b


:06-figures
echo.
echo === Test: 06-figures (fig label + nolabel + fig-group) ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/06-figures.xml' ^
  -output:result=out/06-figures.xml
fc /b expected\06-figures.xml out\06-figures.xml
exit /b

:07-tables
echo.
echo === Test: 07-tables (labeled + floating boxed-text) ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/07-tables.xml' ^
  -output:result=out/07-tables.xml
fc /b expected\07-tables.xml out\07-tables.xml
exit /b

:08-parallel
echo.
echo === Test: 08-parallel (parallel + parallel-*-rtl + righttoleft) ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/08-parallel.xml' ^
  -output:result=out/08-parallel.xml
fc /b expected\08-parallel.xml out\08-parallel.xml
exit /b

:09-blocks
echo.
echo === Test: 09-blocks (disp-quote + rtlblockquote + epigraph + preformat + attrib) ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/09-blocks.xml' ^
  -output:result=out/09-blocks.xml
fc /b expected\09-blocks.xml out\09-blocks.xml
exit /b

:10-verse
echo.
echo === Test: 10-verse (verse + verse-centered + verse-line/attrib + parallel-verse) ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/10-verse.xml' ^
  -output:result=out/10-verse.xml
fc /b expected\10-verse.xml out\10-verse.xml
exit /b

:00-pi-survival
echo.
echo === Test: 00-pi-survival (PIs ueberleben alle Paesse + Primitive) ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/00-pi-survival.xml' ^
  -output:result=out/00-pi-survival.xml
fc /b expected\00-pi-survival.xml out\00-pi-survival.xml
exit /b

:11-strips
echo.
echo === Test: 11-strips (p:unwrap p-wrapper + p:delete fn/label + aff-id) ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/11-strips.xml' ^
  -output:result=out/11-strips.xml
fc /b expected\11-strips.xml out\11-strips.xml
exit /b

:12-anchor-default
echo.
echo === Test: 12-anchor-default (boxed-text ohne @position bekommt position=anchor) ===
call morgana ../../pub/_assets/xproc/cleanup.xpl ^
  -option:source-href='!INPUTS_DIR!/12-anchor-default.xml' ^
  -output:result=out/12-anchor-default.xml
fc /b expected\12-anchor-default.xml out\12-anchor-default.xml
exit /b

:04-load-morgana
echo.
echo === Test: 04-load-morgana (explicit p:load, no suppress options yet) ===
call morgana identity-with-load.xpl ^
  -catalogs=%CATALOG% ^
  -output:result=out/04-load-morgana.xml
exit /b

