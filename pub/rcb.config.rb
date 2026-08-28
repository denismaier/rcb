# rcb.config.rb - Publisher-level build config
# Wird von rcb.rb vor allen rcb.rake-Dateien geladen.

CFG['publisher_name']   = 'Default Publisher'
CFG['build_dir']        = '.build'
CFG['output_dir']       = 'output'
CFG['assets_dir']       = '_assets'
CFG['image_web_dir']    = 'images-web'
CFG['image_tool']       = 'magick'
CFG['image_max_width']  = 1200
CFG['image_quality']    = 85
CFG['jing_jar']         = 'C:/tools/jing/bin/jing.jar'
CFG['schxslt2_xsl']     = 'C:/tools/schxslt2/transpile.xsl'
CFG['saxon_he_jar']     = 'C:/tools/saxon/saxon-he-12.5.jar'
# Pandoc als gepinnter Pfad, nicht via PATH — Reproduzierbarkeit über
# Version, nicht über "was auch gerade installiert ist". Per-Level
# überschreibbar (z.B. Update-Test auf 3.10.2). Siehe Memory project_pandoc_update_planned.
CFG['pandoc_cmd']       = 'C:/tools/pandoc/3.10.2/pandoc.exe'

# Section-Heading-Nummerierung abschalten (XSLT: kein <label> im JATS;
# ConTeXt: keine Heading-Nummern im PDF). Default false = Nummerierung an
# (heutiges Production-Verhalten). Per-Level überschreibbar in
# journal/volume/article rcb.config.rb. Steuert beide Seiten jointly aus
# einer Quelle (legacy-Makefile-Pendant: nonumheadings-Variable); s.
# cleanup.xpl <p:choose> + layout.tex \startmode[nonumheadings].
CFG['nonumheadings']     = false
