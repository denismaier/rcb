# rcb.config.local.example.rb
#
# Copy this file to rcb.config.local.rb (in the same directory) and
# uncomment/edit the lines you need. rcb.config.local.rb is gitignored
# and loads at the end of rcb.config.rb, so it overrides the PATH-based
# defaults. Use this for machine-specific absolute tool paths — e.g. a
# pinned Pandoc version or exact JAR locations.
#
# The defaults in rcb.config.rb assume the tools are on PATH (pandoc,
# magick, context, morgana, zip) and bare JAR names (saxon-he.jar, jing.jar,
# schxslt2/transpile.xsl). Set these only if your layout differs.
#
# ENV vars (RCB_PANDOC_CMD, RCB_SAXON_HE_JAR, RCB_JING_JAR,
# RCB_SCHXSLT2_XSL) are an alternative to this file.

# CFG['pandoc_cmd']   = 'C:/tools/pandoc/3.10.2/pandoc.exe'
# CFG['saxon_he_jar'] = 'C:/tools/saxon/saxon-he-12.5.jar'
# CFG['jing_jar']      = 'C:/tools/jing/bin/jing.jar'
# CFG['schxslt2_xsl']  = 'C:/tools/schxslt2/transpile.xsl'