# rcb.config.local.example.rb
#
# Copy this file to rcb.config.local.rb (in the same directory) and
# uncomment/edit the lines you need. rcb.config.local.rb is gitignored
# and loads at the end of rcb.config.rb, so it overrides the PATH-based
# defaults. Use this for machine-specific absolute tool paths — e.g. a
# pinned Pandoc version or exact JAR locations.
#
# The defaults in rcb.config.rb assume the tools are on PATH (pandoc,
# magick, morgana, context, zip, java, transform) and bare JAR/XSL names
# (saxon-he.jar, jing.jar, schxslt2/transpile.xsl). Set these only if
# your layout differs.
#
# ENV vars (RCB_PANDOC_CMD, RCB_SAXON_HE_JAR, RCB_JING_JAR,
# RCB_SCHXSLT2_XSL, RCB_XPROC_CMD, RCB_CONTEXT_CMD, RCB_ZIP_CMD,
# RCB_JAVA_CMD, RCB_XSLT_CMD, RCB_IMAGE_TOOL) are an alternative to this
# file.

# CFG['pandoc_cmd']    = 'C:/tools/pandoc/3.10.2/pandoc.exe'
# CFG['saxon_he_jar']  = 'C:/tools/saxon/saxon-he-12.5.jar'
# CFG['jing_jar']      = 'C:/tools/jing/bin/jing.jar'
# CFG['schxslt2_xsl']  = 'C:/tools/schxslt2/transpile.xsl'
# CFG['xproc_cmd']     = 'C:/tools/morgana/morgana.bat'   # XProc runner (default: morgana)
# CFG['context_cmd']   = 'C:/context/tex/texmf-windows/bin/context.exe'
# CFG['zip_cmd']       = 'C:/tools/zip/zip.exe'
# CFG['java_cmd']      = 'C:/tools/jdk/bin/java.exe'
# CFG['xslt_cmd']      = 'C:/tools/saxon/transform.bat'   # XSLT runner (default: Saxon transform)
# CFG['image_tool']    = 'C:/tools/ImageMagick/magick.exe' # convert_images (default: magick)

# Behavior flags (defaults siehe rcb.config.rb bzw. pub/README.md):
# CFG['context_mode']       = 'article' # ConTeXt --mode= (jats.tex Layout-Modi)
# CFG['output_images']      = true      # Bilder ins HTML/Output-Verzeichnis kopieren
# CFG['extract_auto_apply'] = true      # extract_metadata ohne interaktive Nachfrage
# CFG['nonumheadings']      = true      # Section-Nummerierung aus (Doku siehe rcb.config.rb)