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
# External tools — defaults assume the tools are on PATH (bare command
# names). For machine-specific absolute paths (e.g. a pinned Pandoc
# version or a JAR location), copy rcb.config.local.example.rb to
# rcb.config.local.rb (gitignored) and override there — it loads after
# these defaults. ENV vars (RCB_PANDOC_CMD, RCB_SAXON_HE_JAR, RCB_JING_JAR,
# RCB_SCHXSLT2_XSL, RCB_XPROC_CMD, RCB_CONTEXT_CMD, RCB_ZIP_CMD,
# RCB_JAVA_CMD, RCB_XSLT_CMD) also win over the bare defaults.
CFG['jing_jar']         = ENV['RCB_JING_JAR']     || 'jing.jar'
CFG['schxslt2_xsl']     = ENV['RCB_SCHXSLT2_XSL']  || 'schxslt2/transpile.xsl'
CFG['saxon_he_jar']     = ENV['RCB_SAXON_HE_JAR'] || 'saxon-he.jar'
CFG['pandoc_cmd']       = ENV['RCB_PANDOC_CMD']   || 'pandoc'
# xproc_cmd/xslt_cmd are function-named (what the step runs, not which
# tool); the bare defaults are the Morgana/Saxon CLIs and the invocation
# flags in rcb.rake remain tool-specific.
CFG['xproc_cmd']        = ENV['RCB_XPROC_CMD']    || 'morgana'
CFG['context_cmd']      = ENV['RCB_CONTEXT_CMD']  || 'context'
CFG['zip_cmd']          = ENV['RCB_ZIP_CMD']      || 'zip'
CFG['java_cmd']         = ENV['RCB_JAVA_CMD']     || 'java'
CFG['xslt_cmd']         = ENV['RCB_XSLT_CMD']     || 'transform'

# Section-Heading-Nummerierung abschalten (XSLT: kein <label> im JATS;
# ConTeXt: keine Heading-Nummern im PDF). Default false = Nummerierung an
# (heutiges Production-Verhalten). Per-Level überschreibbar in
# journal/volume/article rcb.config.rb. Steuert beide Seiten jointly aus
# einer Quelle (legacy-Makefile-Pendant: nonumheadings-Variable); s.
# cleanup.xpl <p:choose> + layout.tex \startmode[nonumheadings].
CFG['nonumheadings']     = false

# Local override (gitignored): set machine-specific tool paths here.
# See rcb.config.local.example.rb. Loads after the defaults above, so a
# local file wins; deeper-level rcb.config.rb files still load after this
# whole file and can override further.
local_config = File.expand_path('rcb.config.local.rb', __dir__)
load local_config if File.exist?(local_config)
