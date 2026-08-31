# rcb.rake - Publisher level configuration
# This is the root of the cascade (marked by .rcbroot)

# ============================================
# Requires (available for all tasks)
# ============================================
require 'pathname'
require 'fileutils'
require 'open3'
require 'yaml'
require 'tmpdir'

# ============================================
# Path Constants (for use in all tasks)
# ============================================
# CFG is populated by rcb.config.rb files across the cascade, loaded by rcb.rb
# before any rcb.rake. See publisher/rcb.config.rb for defaults.
BUILD_DIR = Pathname.new(CFG['build_dir'])
OUTPUT_DIR = Pathname.new(CFG['output_dir'])

# ============================================
# Infrastructure Tasks
# ============================================

desc "Validate configuration"
task :validate_config do
  required = ['build_dir', 'output_dir']
  missing = required.select { |k| !CFG.key?(k) }

  if missing.any?
    raise "Missing required CFG keys: #{missing.join(', ')}"
  end

  puts "Config validation passed: #{CFG.keys.size} keys defined"
end

desc "Clean build directory contents"
task :clean_build do


  unless BUILD_DIR.exist?
    puts "Nothing to clean: #{BUILD_DIR} does not exist"
    next
  end

  removed_count = 0
  BUILD_DIR.each_child do |item|
    if item.directory?
      item.rmtree
    else
      item.delete
    end
    removed_count += 1
  end

  puts "Cleaned #{removed_count} items from #{BUILD_DIR}"
end

# ============================================
# Directory Tasks (Rake native - idempotent)
# ============================================

build_subdirs = %w[source md xml html pdf _assets images-web zip refs]

directory CFG['build_dir']
build_subdirs.each { |d| directory "#{CFG['build_dir']}/#{d}" }

desc "Setup build directory structure"
task :setup_build => [CFG['build_dir']] + build_subdirs.map { |d| "#{CFG['build_dir']}/#{d}" } do
  puts "[setup_build] Directories ready in #{BUILD_DIR}/"
end

# Output directory tasks
output_subdirs = %w[xml html pdf]

directory CFG['output_dir']
output_subdirs.each { |d| directory "#{CFG['output_dir']}/#{d}" }

desc "Setup output directory structure"
task :setup_output => [CFG['output_dir']] + output_subdirs.map { |d| "#{CFG['output_dir']}/#{d}" } do
  puts "[setup_output] Directories ready in #{OUTPUT_DIR}/"
end

# ============================================
# Init Meta-Task
# ============================================

desc "Initialize build workspace (setup dirs, prepare assets, merge metadata)"
task :init_build => [:setup_build, :setup_output, :prepare_assets, :prepare_metadata] do
  puts "[init_build] Workspace ready!"
end

# ============================================
# Metadata Tasks
# ============================================

desc "Extract metadata from source file and merge into article's metadata.yaml (interactive)"
task :extract_metadata => [:prepare_assets] do

  basename = CFG['basename'] || 'article'
  source_format = CFG['source_format'] || 'docx'
  metadata_target = Pathname.new('metadata.yaml')

  # Load existing metadata to get protected fields
  existing = {}
  protected_fields = Set.new

  if metadata_target.exist?
    existing = YAML.load_file(metadata_target) || {}
    extract_config = existing['_extract'] || {}
    protected_fields = Set.new(extract_config['protect'] || [])
  end

  # Setup paths based on source_format
  case source_format
  when 'docx'
    source_file = Pathname.new("source/#{basename}.docx")
    template_name = 'metadata-extract.txt'
    pandoc_from = 'docx'
  when 'md'
    source_file = Pathname.new("source/#{basename}.md")
    template_name = 'metadata-extract.txt'
    pandoc_from = 'markdown'
  else
    raise "Unsupported source_format: #{source_format}"
  end

  extract_template_name = "_assets/pandoc-templates/#{template_name}"

  # Find template (search from current dir up the cascade)
  template_candidates = []
  $rcb_cascade_dirs&.reverse&.each do |dir|
    template_candidates << Pathname.new(dir) / extract_template_name
    template_candidates << Pathname.new(dir) / "_assets" / "pandoc-templates" / template_name
  end
  template_candidates << Pathname.new(extract_template_name)

  template_path = template_candidates.find { |c| c.exist? }

  raise "Template not found: #{template_name}" unless template_path
  raise "Source not found: #{source_file}" unless source_file.exist?

  # Extract metadata from source using pandoc

  cmd = [CFG['pandoc_cmd'], source_file.to_s,
         "--from=#{pandoc_from}",
         '--to=markdown',
         "--template=#{template_path}",
         '--wrap=none']

  stdout, _stderr, status = Open3.capture3(*cmd)
  raise "Pandoc extraction failed" unless status.success?

  # Parse YAML output
  yaml_content = stdout.strip
  if yaml_content.start_with?('---')
    parts = yaml_content.split('---', 3)
    yaml_content = parts[1].strip if parts.size >= 2
  end

  extracted = YAML.load(yaml_content) || {}
  extracted.delete('_extract')  # Don't merge internal fields

  # Merge with protection tracking
  merged = Marshal.load(Marshal.dump(existing))  # Deep copy
  changes = { added: [], updated: [], skipped: [] }

  extracted.each do |key, value|
    # Check if this field is protected
    is_protected = protected_fields.any? do |p|
      key == p || p.start_with?("#{key}.") || key.start_with?("#{p}.")
    end

    if is_protected
      changes[:skipped] << key
      next
    end

    if !existing.key?(key)
      merged[key] = Marshal.load(Marshal.dump(value))
      changes[:added] << key
    elsif existing[key].is_a?(Hash) && value.is_a?(Hash)
      merged[key] = existing[key].merge(value)
      changes[:updated] << "#{key} (merged)"
    elsif existing[key] != value
      merged[key] = value
      changes[:updated] << "#{key}: '#{existing[key]}' → '#{value}'"
    end
  end

  # Print source info
  puts "\n[extract_metadata] Source: #{source_format} (#{source_file.basename})"

  # Check if there are changes to apply
  changes_exist = !changes[:added].empty? || !changes[:updated].empty?

  if changes_exist
    # Show diff-style preview
    puts "\n" + "=" * 50
    puts "PROPOSED CHANGES:"
    puts "=" * 50
    puts "\n[ADD] #{changes[:added].join(', ')}" unless changes[:added].empty?
    unless changes[:updated].empty?
      puts "\n[UPDATE]"
      changes[:updated].each { |c| puts "  - #{c}" }
    end
    puts "\n[SKIPPED - protected] #{changes[:skipped].join(', ')}" unless changes[:skipped].empty?
    puts "=" * 50

    # Check auto-apply from --yes flag or cfg
    auto_apply = $rcb_options&.dig(:yes) || CFG['extract_auto_apply'] || false

    if auto_apply
      apply = true
      puts "\n[Auto-apply mode]"
    else
      print "\nApply these changes? [y/N]: "
      response = STDIN.gets.strip.downcase
      apply = response == 'y' || response == 'yes'
    end
  else
    apply = true
    puts "\n[extract_metadata] No changes detected"
  end

  # Only backup and write if confirmed
  if apply && changes_exist
    backup = metadata_target.sub('.yaml', '.yaml.bak')
    FileUtils.cp(metadata_target, backup)
    puts "[extract_metadata] Backup: #{backup.basename}"

    File.write(metadata_target, merged.to_yaml)
    puts "[extract_metadata] Applied #{changes[:added].size} additions, #{changes[:updated].size} updates"
  elsif !apply
    puts '[extract_metadata] Changes NOT applied (skipped)'
  elsif !changes_exist
    puts "[extract_metadata] Skipped (protected): #{changes[:skipped].join(', ')}" unless changes[:skipped].empty?
  end
end

metadata_resolved_path = (BUILD_DIR / 'metadata-resolved.yaml').to_s
metadata_sources = RCB.load_manifest['metadata']

file metadata_resolved_path => metadata_sources do |t|
  resolved = {}
  metadata_sources.each do |md_path|
    level_md = YAML.load_file(md_path) || {}

    # Deep merge: level-specific keys override parent keys
    level_md.each do |key, value|
      if resolved.key?(key)
        if resolved[key].is_a?(Hash) && value.is_a?(Hash)
          resolved[key] = resolved[key].merge(value)
        else
          resolved[key] = value
        end
      else
        resolved[key] = Marshal.load(Marshal.dump(value))
      end
    end
  end

  # DOI Construction: {doi_prefix}.{year}.{doi_article_number}
  doi_prefix = (resolved.dig('journal', 'doi_prefix') || '').to_s
  year = (resolved.dig('date', 'year') || '').to_s
  doi_article_number = (resolved.dig('article', 'doi_article_number') || '').to_s

  if !doi_prefix.empty? && !year.empty? && !doi_article_number.empty?
    doi_id = "#{doi_prefix}.#{year}.#{doi_article_number}"
    doi_url = "https://doi.org/#{doi_id}"

    resolved['article'] ||= {}
    resolved['article']['doi'] = doi_url
    resolved['article']['doi_id'] = doi_id

    puts "[prepare_metadata] DOI constructed: #{doi_url}"
  end

  File.write(t.name, resolved.to_yaml)
  puts "[prepare_metadata] merged #{metadata_sources.size} files -> #{t.name}"
end

desc "Load and merge metadata.yaml from all cascade levels with DOI construction"
task :prepare_metadata => [:prepare_assets, metadata_resolved_path]

# ============================================
# Pipeline Tasks
# ============================================

# ============================================
# Image Tasks
# ============================================

image_exts = %w[.tiff .tif .jpg .jpeg .png .gif]
tiff_exts  = %w[.tiff .tif]
image_targets = []

# Lade alle Quell-Bilder aus dem Manifest
RCB.load_manifest['sources'].each do |rel_path, origin|
  ext = File.extname(rel_path).downcase
  next unless image_exts.include?(ext)

  # Target-Filename: TIFFs werden zu JPG umbenannt, sonst Original-Basename
  target_name = tiff_exts.include?(ext) \
    ? File.basename(rel_path, ext) + '.jpg'
    : File.basename(rel_path)
  target = (BUILD_DIR / 'images-web' / target_name).to_s
  image_targets << target

  # Override-Lookup: Key ist das ERWARTETE Target-Filename (nicht Original-Basename),
  # damit Override für .tif-Originals als .jpg geliefert werden kann/muss.
  override_rel_path = File.join("images-web", target_name)
  manifest_sources = RCB.load_manifest['sources']

  if manifest_sources.key?(override_rel_path)
    # Manueller Override existiert im Manifest
    copied_override = (BUILD_DIR / RCB::SOURCE_DIR / override_rel_path).to_s

    file target => [copied_override] do |t|
      FileUtils.mkdir_p(File.dirname(t.name))
      FileUtils.cp(t.source, t.name)
      puts "[convert_images] #{File.basename(t.name)} (manual override)"

      # Stale-Check gegen Origin-Pfade (kopierte .build-Dateien haben frische Build-mtimes)
      override_origin = manifest_sources[override_rel_path]
      if origin && File.mtime(origin) > File.mtime(override_origin)
        RCB.warn "STALE IMAGE OVERRIDE: Original (#{File.basename(origin)}) ist neuer als Override — convertiere neu"
      end
    end
  else
    # Kein Override: automatische Konvertierung via ImageMagick
    copied_source = (BUILD_DIR / RCB::SOURCE_DIR / rel_path).to_s

    file target => [copied_source] do |t|
      FileUtils.mkdir_p(File.dirname(t.name))
      cmd = [CFG['image_tool'], t.source,
             '-resize', "#{CFG['image_max_width']}x>",
             '-quality', CFG['image_quality'].to_s,
             t.name]
      stdout, stderr, status = Open3.capture3(*cmd)
      raise "ImageMagick failed on #{File.basename(t.source)}: #{stderr}" unless status.success?
      puts "[convert_images] #{File.basename(t.name)}"
    end
  end
end

desc "Convert images for web/screen display (ImageMagick)"
task :convert_images => image_targets do
  puts "[convert_images] #{image_targets.size} images ready"
end

image_output_targets = []

image_targets.each do |web_src|
  img_basename = File.basename(web_src)

  [(BUILD_DIR / 'html').to_s, (OUTPUT_DIR / 'html').to_s].each do |dst_dir|
    dst = File.join(dst_dir, img_basename)
    image_output_targets << dst

    file dst => [web_src] do |t|
      FileUtils.mkdir_p(File.dirname(t.name))
      FileUtils.cp(t.source, t.name)
      puts "[images_to_output] #{File.basename(t.name)}"
    end
  end
end

if CFG['output_images']
  RCB.load_manifest['sources'].each do |rel_path, _origin|
    ext = File.extname(rel_path).downcase
    next unless image_exts.include?(ext)

    origin_copy = (BUILD_DIR / RCB::SOURCE_DIR / rel_path).to_s
    target = (OUTPUT_DIR / 'images' / File.basename(rel_path)).to_s
    image_output_targets << target

    file target => [origin_copy] do |t|
      FileUtils.mkdir_p(File.dirname(t.name))
      FileUtils.cp(t.source, t.name)
      puts "[images_to_output] #{File.basename(t.name)} (original)"
    end
  end
end

desc "Copy images to HTML and output directories"
task :images_to_output => image_output_targets do
  puts "[images_to_output] #{image_output_targets.size} images ready"
end

# ============================================
# Pipeline Tasks
# ============================================

basename = CFG['basename']

# --- require_article ---
# Pipeline-Tasks brauchen Artikel-Kontext: CFG['basename'] wird erst von
# article-level rcb.config.rb gesetzt. Fail-fast statt nil in Task-Namen.
task :require_article do
  unless CFG['basename']
    raise "Pipeline tasks require an article context: CFG['basename'] is not set. Run from an article directory."
  end
end

# ============================================
# MD Pipeline
# ============================================

# --- source_to_md ---
# Pipeline-Einstieg: produziert raw MD aus der Autorenquelle.
# Jedes Format hat eine Registrierfunktion, SOURCE_FORMATS ist die Lookup-Tabelle.

def register_docx_to_md(src, dst)
  image_marker_filter = (BUILD_DIR / '_assets/pandoc-lua-filters/image-markers.lua').to_s

  file dst => [src, image_marker_filter] do |t|
    FileUtils.mkdir_p(File.dirname(t.name))
    puts '[source_to_md] Converting DOCX to Markdown using pandoc...'

    # Kein --extract-media: embedded images werden bewusst nicht unterstützt.
    # Bilder kommen extern über source/images/, Autor referenziert sie via
    # image-markers (<<IMG: bild.jpg | …>>) oder MD-Override.
    cmd = [CFG['pandoc_cmd'], t.source,
           '-o', t.name,
           '--from=docx',
           '--to=markdown-smart',
           '--wrap=none',
           "--lua-filter=#{image_marker_filter}"]

    _stdout, stderr, status = Open3.capture3(*cmd)
    raise "Pandoc conversion failed: #{stderr}" unless status.success?

    puts "[source_to_md] #{File.basename(t.name)}"
  end
end

# Platzhalter für künftige Formate:
# def register_odt_to_md(src, dst) ... end    # pandoc --from=odt
# def register_tex_to_md(src, dst) ... end    # pandoc --from=latex
# def register_md_passthrough(src, dst) ... end  # direkter Copy; Override-Mechanismus entfällt
# 'xml' ist Sonderfall: eigener Pipeline-Einstieg, nicht hier

SOURCE_FORMATS = {
  'docx' => { ext: '.docx', register: method(:register_docx_to_md) },
  # 'odt'  => { ext: '.odt',  register: method(:register_odt_to_md) },
  # 'tex'  => { ext: '.tex',  register: method(:register_tex_to_md) },
  # 'md'   => { ext: '.md',   register: method(:register_md_passthrough) },
}.freeze

source_to_md = {
  out:  (BUILD_DIR / "md/01-md-raw-#{basename}.md").to_s,
  desc: "Convert source to raw Markdown (honors CFG['source_format']; optional MD override)",
}

source_format = CFG['source_format'] || 'docx'
fmt = SOURCE_FORMATS.fetch(source_format) do
  raise "Unsupported CFG['source_format']: #{source_format.inspect}. Known: #{SOURCE_FORMATS.keys}"
end

source_to_md[:in] = (BUILD_DIR / "source/#{basename}#{fmt[:ext]}").to_s

# Override-Mechanismus (orthogonal zu source_format): hand-edierte MD unter
# source/<basename>.md übersteuert die automatische Konversion. Lade-Zeit-Fork:
# ist die Override-MD im Manifest, definieren wir einen Override-File-Task
# statt des Format-Konverters — so bleibt Rake's Dependency-Chain sauber.
override_manifest_key = "#{basename}.md"
manifest_sources = RCB.load_manifest['sources']
if manifest_sources.key?(override_manifest_key)
  override_build   = (BUILD_DIR / "source/#{override_manifest_key}").to_s
  compare_file     = "#{source_to_md[:out]}.compare"
  source_origin      = manifest_sources["#{basename}#{fmt[:ext]}"]
  override_origin  = manifest_sources[override_manifest_key]

  file source_to_md[:out] => [override_build, source_to_md[:in]] do |t|
    FileUtils.mkdir_p(File.dirname(t.name))
    # Stale-Check gegen Origin-Pfade (kopierte .build-Dateien haben frische Build-mtimes)
    is_stale = source_origin && File.mtime(source_origin) > File.mtime(override_origin)
    compare_file = is_stale ? "#{t.name}.stale" : "#{t.name}.compare"

    # Beide Varianten aufräumen — bei Zustandswechsel soll nur die aktuelle übrig bleiben
    [".compare", ".stale"].each do |suffix|
      old = "#{t.name}#{suffix}"
      File.delete(old) if File.exist?(old) && old != compare_file
    end

    # Source-Format zum Vergleich konvertieren — immer, damit Autor jederzeit diffen kann
    FileUtils.mkdir_p(File.dirname(compare_file))
    cmd = [CFG['pandoc_cmd'], source_to_md[:in], '-o', compare_file,
           "--from=#{source_format}", '--to=markdown-smart', '--wrap=none']
    _stdout, stderr, status = Open3.capture3(*cmd)
    raise "Pandoc compare-conversion failed: #{stderr}" unless status.success?

    # Override als eigentlichen Output kopieren
    FileUtils.cp(override_build, t.name)

    if is_stale
      RCB.warn "STALE OVERRIDE: #{source_format.upcase} (#{File.basename(source_origin)}) ist neuer als Override — Vergleich in #{File.basename(compare_file)}"
    end
    puts "[source_to_md] Manual MD override (Vergleich: #{File.basename(compare_file)})"
  end
else
  fmt[:register].call(source_to_md[:in], source_to_md[:out])
end

desc source_to_md[:desc]
task :source_to_md => [:require_article, source_to_md[:out]]

# --- promote_md ---
# Befördert das auto-generierte rohe MD nach source/<basename>.md als
# Override-Basis zum Editieren. Nimmt das manuelle copy+rename aus dem
# Override-Workflow heraus (siehe docs/user/article-workflow.md Schritt 6).
# Einmalig: existiert der Override schon, wird nicht überschrieben.
# Dependency auf source_to_md stellt sicher, dass das rohe MD aktuell ist
# (Rake mtime-gated → normalerweise ein No-op) und der Task auch nach
# clean_build funktioniert. Override greift erst beim nächsten Build, da
# das Manifest zur Ladezeit vor Task-Ausführung steht.
desc "Promote auto-generated MD to source/<basename>.md as override basis for editing"
task :promote_md => [:source_to_md] do
  override = Pathname.new("source/#{basename}.md")
  if override.exist?
    raise "Override already exists: #{override} — promote_md is a one-time step; edit the existing file instead."
  end
  raw = BUILD_DIR / "md/01-md-raw-#{basename}.md"
  FileUtils.cp(raw, override)
  puts "[promote_md] #{raw.basename} → #{override}"
  puts "[promote_md] Override aktiv beim nächsten Build; .compare/.stale zeigt ob das DOCX neuer ist."
end

# --- md_final ---
# Keep für Konsistenz; kopiert direkt von source_to_md (Typografie in XML)

md_final = {
  in:   source_to_md[:out],
  out:  (BUILD_DIR / "md/99-md-final-#{basename}.md").to_s,
  desc: "Finalize markdown (copy last MD step)",
}

file md_final[:out] => [md_final[:in]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  FileUtils.cp(t.source, t.name)
  puts "[md_final] #{File.basename(t.source)} → #{File.basename(t.name)}"
end

desc md_final[:desc]
task :md_final => [:require_article, md_final[:out]]

# ============================================
# XML Pipeline
# ============================================

# --- md_to_xml ---

lua_filters = %w[
  author-notes-to-meta
  abstract-to-meta
  auto-classify-refs
  auto-classify-app-figures
  html-tables
  pandoc-list-table
  list-table
  versify
  classes-to-attr
].map { |f| (BUILD_DIR / "_assets/pandoc-lua-filters/#{f}.lua").to_s }

md_to_xml = {
  in:   md_final[:out],
  out:  (BUILD_DIR / "xml/01-xml-raw-#{basename}.xml").to_s,
  tool: CFG['pandoc_cmd'],
  template: (BUILD_DIR / '_assets/pandoc-templates/jats_publishing.template').to_s,
  metadata: (BUILD_DIR / 'metadata-resolved.yaml').to_s,
  desc: "Convert Markdown to JATS XML with metadata injection",
}

file md_to_xml[:out] => [md_to_xml[:in], md_to_xml[:template], md_to_xml[:metadata], *lua_filters] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  puts '[md_to_xml] Converting to JATS XML...'

  filter_args = lua_filters.flat_map { |f| ['--lua-filter', f] }

  cmd = [md_to_xml[:tool], t.source,
         '--to=jats',
         '--from=markdown-smart',
         '--standalone',
         "--template=#{md_to_xml[:template]}",
         "--metadata-file=#{md_to_xml[:metadata]}",
         *filter_args,
         '-o', t.name]

  stdout, stderr, status = Open3.capture3(*cmd)
  raise "Pandoc XML conversion failed: #{stderr}" unless status.success?

  puts "[md_to_xml] #{File.basename(t.name)}"
end

desc md_to_xml[:desc]
task :md_to_xml => [:require_article, md_to_xml[:out]]

# --- xml_clean ---

# XProc-Cleanup-Pipeline (Phase 20a, portiert 2026-07-08): die ehemals
# monolithische cleanup.xsl ist aufgeloest in cleanup.xpl + modulare
# p:xslt-Steps (_back-moves/_sections/_figures/_tables/_blocks/_anchor-default)
# plus XProc-Strip-Primitive. Serialisierung liegt in cleanup.xpl p:output;
# DTD-Default-Suppress liegt am <p:load> (mox:expand-default-attributes=false(),
# ersetzt Saxons -expand:off). nonumheadings: CFG['nonumheadings'] steuert
# die Section-Numbering jointly (XSLT + ConTeXt); truthy -> hier
# -option:nonumheadings='true' an Morgana (Default '' = Numbering an).
# Siehe cleanup.xpl <p:choose> + layout.tex \startmode[nonumheadings].
xml_clean = {
  in:      md_to_xml[:out],
  out:     (BUILD_DIR / "xml/02-xml-clean-#{basename}.xml").to_s,
  tool:    CFG['xproc_cmd'],
  xpl:     (BUILD_DIR / '_assets/xproc/cleanup.xpl').to_s,
  catalog: (BUILD_DIR / '_assets/jats-dtd/catalog-jats-v1-2-no-base.xml').to_s,
  desc:    "Clean XML via XProc pipeline (Morgana)",
}

xproc_modules = %w[_back-moves _sections _figures _tables _blocks _anchor-default]
  .map { |m| (BUILD_DIR / "_assets/xproc/#{m}.xsl").to_s }

# Load-Zeit: Asset-Closures für Catalog/RNG-resolvende Tasks. Standalone nach
# clean_build brauchen diese Tasks nicht nur ihren primären Input, sondern den
# gesamten jats-dtd- bzw. jats-rng-Baum (Catalog/RNG referenzieren .ent/.dtd-
# bzw. .ent.rng-Dateien relativ). :prepare_assets staged das unter build_all
# komplett; standalone nur die Task-eigenen Deps — ohne diese Closure scheitert
# Morgana/Jing still (Verifikation 2026-08-24: xml_clean schreib keine Output-
# Datei, validate_rng brach an JATS-ali-namespace1.ent.rng).
jats_dtd_assets = RCB.load_manifest['assets'].keys
  .select { |k| k.start_with?('jats-dtd/') }
  .map    { |k| (BUILD_DIR / RCB::ASSETS_DIR / k).to_s }
  .sort

jats_rng_assets = RCB.load_manifest['assets'].keys
  .select { |k| k.start_with?('jats-rng/') }
  .map    { |k| (BUILD_DIR / RCB::ASSETS_DIR / k).to_s }
  .sort

file xml_clean[:out] => [xml_clean[:in], xml_clean[:xpl], xml_clean[:catalog], *xproc_modules, *jats_dtd_assets] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  puts '[xml_clean] Applying XProc pipeline (Morgana)...'

  # Morgana-CLI: Pipeline-Datei = erstes positionelles Argument, -catalogs=
  # muss frueh stehen (sonst ignoriert Morgana den Catalog still).
  # -option:source-href='<uri>' ist ein XPath-String-Literal; Single-Quotes
  # werden als literale Zeichen uebergeben (Open3 array-Form -> keine Shell).
  # <p:load href> loest den Wert als URI auf (relativ zur .xpl-Base-URI) —
  # daher absoluter file://-URI (Forward-Slashes), kein raw-OS-Pfad
  # (sonst 'URI does not specify a valid host name').
  src = 'file:///' + File.expand_path(t.source).tr('\\', '/')
  cmd = [xml_clean[:tool],
         xml_clean[:xpl],
         "-catalogs=#{xml_clean[:catalog]}",
         "-option:source-href='#{src}'",
         "-output:result=#{t.name}"]
  cmd << "-option:nonumheadings='true'" if CFG['nonumheadings']

  stdout, stderr, status = Open3.capture3(*cmd)
  raise "XProc cleanup failed: #{stderr}" unless status.success?

  puts "[xml_clean] #{File.basename(t.name)}"
end

desc xml_clean[:desc]
task :xml_clean => [:require_article, xml_clean[:out]]

# --- validate_xml_rng ---

validate_xml_rng = {
  in:     xml_clean[:out],
  out:    (BUILD_DIR / "xml/03-xml-validated-#{basename}.xml").to_s,
  tool:   CFG['java_cmd'],
  jar:    CFG['jing_jar'],
  schema: (BUILD_DIR / '_assets/jats-rng/JATS-journalpublishing1.rng').to_s,
  desc:   "Validate cleaned XML against JATS RNG schema (jing)",
}

file validate_xml_rng[:out] => [validate_xml_rng[:in], validate_xml_rng[:schema], *jats_rng_assets] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  puts '[validate_xml_rng] Validating XML against JATS RNG schema...'

  # Jing's bundled xerces tries to resolve the external DTD; strip the DOCTYPE
  # in a temp copy so RNG validation runs without needing a catalog resolver.
  no_doctype = "#{t.source}.no-doctype"
  File.write(no_doctype, File.read(t.source).sub(/<!DOCTYPE[^>]*>\s*/m, ''))

  cmd = [validate_xml_rng[:tool],
         '-jar', validate_xml_rng[:jar],
         validate_xml_rng[:schema],
         no_doctype]

  stdout, stderr, status = Open3.capture3(*cmd)
  File.delete(no_doctype) if File.exist?(no_doctype)
  raise "JATS RNG validation failed:\n#{stdout}#{stderr}" unless status.success?

  FileUtils.cp(t.source, t.name)
  puts "[validate_xml_rng] OK: #{File.basename(t.name)}"
end

desc validate_xml_rng[:desc]
task :validate_xml_rng => [:require_article, validate_xml_rng[:out]]

# --- validate_xml_schematron ---
# SchXslt2 transpiliert .sch zu .xsl. Die Transpilation passiert automatisch,
# wenn die .xsl Datei fehlt oder veraltet ist.

# Load-Zeit: alle .sch aus dem Manifest finden → file-deps für korrekte mtime-Rebuilds
sch_source_files = RCB.load_manifest['assets'].keys
  .select { |k| k =~ %r{^schematron/.*\.sch$} }
  .reject { |k| File.basename(k).start_with?('_') }  # generierte Wrapper ausschliessen
  .map    { |k| (BUILD_DIR / RCB::ASSETS_DIR / k).to_s }
  .sort

validate_xml_schematron = {
  in:         validate_xml_rng[:out],
  out:        (BUILD_DIR / "xml/04-xml-schematron-valid-#{basename}.xml").to_s,
  saxon_jar:  CFG['saxon_he_jar'],
  sch_files:  sch_source_files,
  wrapper:    (BUILD_DIR / '_assets/schematron/_combined.sch').to_s,
  desc:       "Validate XML against all Schematron rules (Saxon, aggregated via wrapper)",
}

file validate_xml_schematron[:out] => [validate_xml_schematron[:in]] + validate_xml_schematron[:sch_files] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))

  # Ohne Schematron-Regeln (z.B. minimales Journal ohne eigene .sch) gibt es
  # nichts zu validieren — Passthrough statt raise. Regeln liegen typischerweise
  # auf Journal-Ebene; ein Journal ohne welche ist legitim.
  if validate_xml_schematron[:sch_files].empty?
    RCB.warn "Keine Schematron-Regeln im Cascade — überspringe Schematron-Validierung"
    FileUtils.cp(t.source, t.name)
    puts "[validate_xml_schematron] Passthrough (keine Regeln): #{File.basename(t.name)}"
    next
  end

  puts '[validate_xml_schematron] Running Schematron validation...'

  # 1. Wrapper-Content generieren
  wrapper = validate_xml_schematron[:wrapper]
  extends_lines = validate_xml_schematron[:sch_files]
    .map { |f| %Q(  <extends href="#{File.basename(f)}"/>) }
    .join("\n")
  new_content = <<~SCH
    <?xml version="1.0" encoding="UTF-8"?>
    <schema xmlns="http://purl.oclc.org/dsdl/schematron" queryBinding="xslt">
    #{extends_lines}
    </schema>
  SCH

  # 2. Wrapper nur schreiben wenn Inhalt geändert (kein unnötige mtime-Bump → kein unnötiger re-transpile)
  current_content = File.exist?(wrapper) ? File.read(wrapper) : nil
  if current_content != new_content
    File.write(wrapper, new_content)
    puts "[validate_xml_schematron] Wrapper regeneriert (#{validate_xml_schematron[:sch_files].size} .sch eingebunden)"
  end

  # 3. Transpile-Check: .xsl muss neuer sein als Wrapper UND alle referenzierten .sch
  xsl_file = "#{wrapper}.xsl"
  needs_transpile = !File.exist?(xsl_file) ||
                    (validate_xml_schematron[:sch_files] + [wrapper]).any? { |f| File.mtime(xsl_file) < File.mtime(f) }

  if needs_transpile
    puts '[validate_xml_schematron] Transpiling wrapper to .xsl...'
    cmd = [
      CFG['java_cmd'], '-jar', validate_xml_schematron[:saxon_jar],
      '-s:' + wrapper,
      '-xsl:' + CFG['schxslt2_xsl'],
      '-o:' + xsl_file
    ]
    stdout, stderr, status = Open3.capture3(*cmd)
    raise "Schematron transpilation failed: #{stderr}" unless status.success?
    puts "[validate_xml_schematron] Transpilation complete: #{File.basename(xsl_file)}"
  end

  svrl_path = "#{t.name}.svrl.xml"

  # Alten Failure-Report vor neuer Validation wegräumen, damit nur der jüngste übrig bleibt
  File.delete(svrl_path) if File.exist?(svrl_path)

  # Saxon kann mit DOCTYPE nicht umgehen (kein DTD-Resolver). Strippe ihn.
  no_doctype = "#{t.source}.no-doctype"
  File.write(no_doctype, File.read(t.source).sub(/<!DOCTYPE[^>]*>\s*/m, ''))

  # Das XSLT auf das XML anwenden, ergibt SVRL-Report
  cmd = [
    CFG['java_cmd'], '-jar', validate_xml_schematron[:saxon_jar],
    '-s:' + no_doctype,
    '-xsl:' + xsl_file,
    '-o:' + svrl_path
  ]
  stdout, stderr, status = Open3.capture3(*cmd)
  File.delete(no_doctype) if File.exist?(no_doctype)
  raise "Schematron validation failed: #{stderr}" unless status.success?

  # SVRL Output prüfen auf failed-assert — bei Failure bleibt der Report für Inspektion liegen
  svrl_output = File.read(svrl_path)
  if svrl_output.include?('<svrl:failed-assert')
    raise "Schematron validation failed (Report: #{svrl_path}):\n#{svrl_output}"
  end

  # Validation erfolgreich → SVRL wegräumen
  File.delete(svrl_path) if File.exist?(svrl_path)

  FileUtils.cp(t.source, t.name)
  puts "[validate_xml_schematron] OK: #{File.basename(t.name)} (#{validate_xml_schematron[:sch_files].size} rule files passed)"
end

desc validate_xml_schematron[:desc]
task :validate_xml_schematron => [:require_article, validate_xml_schematron[:out]]

# --- xml_typo ---
# Typografische Ersetzungen in XML (nach typo-replacements.py)
# Läuft nach Validierung, da nur Textinhalte geändert werden, keine Attribute/Struktur

xml_typo = {
  in:     validate_xml_schematron[:out],
  out:    (BUILD_DIR / "xml/05-xml-typo-#{basename}.xml").to_s,
  tool:   CFG['xslt_cmd'],
  xsl:    (BUILD_DIR / '_assets/xslt/_typography.xsl').to_s,
  catalog: (BUILD_DIR / '_assets/jats-dtd/catalog-jats-v1-2-no-base.xml').to_s,
  desc:   "Apply typography replacements to XML (XSLT)",
}

file xml_typo[:out] => [xml_typo[:in], xml_typo[:xsl], xml_typo[:catalog]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  puts '[xml_typo] Applying typography replacements (XSLT)...'

  cmd = [xml_typo[:tool],
         "-xsl:#{xml_typo[:xsl]}",
         "-catalog:#{xml_typo[:catalog]}",
         '-expand:off',
         "-s:#{t.source}",
         "-o:#{t.name}"]

  stdout, stderr, status = Open3.capture3(*cmd)
  raise "XSLT typography transformation failed: #{stderr}" unless status.success?

  puts "[xml_typo] #{File.basename(t.name)}"
end

desc xml_typo[:desc]
task :xml_typo => [:require_article, xml_typo[:out]]

# --- xml_final ---

xml_final = {
  in:   xml_typo[:out],
  out:  (BUILD_DIR / "xml/99-xml-final-#{basename}.xml").to_s,
  desc: "Finalize XML (copy, keeps ConTeXt PIs)",
}

file xml_final[:out] => [xml_final[:in]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  FileUtils.cp(t.source, t.name)
  puts "[xml_final] #{File.basename(t.source)} → #{File.basename(t.name)}"
end

desc xml_final[:desc]
task :xml_final => [:require_article, xml_final[:out]]

# --- xml_publish ---

xml_publish = {
  in:   xml_final[:out],
  out:  (BUILD_DIR / "xml/99-xml-publish-#{basename}.xml").to_s,
  desc: "Create publishable XML (remove ConTeXt PIs)",
}

file xml_publish[:out] => [xml_publish[:in]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  puts '[xml_publish] Removing ConTeXt PIs for publication...'

  content = File.read(t.source)
  content.gsub!(/<\?context\s+.*?\?>/, '')
  content.gsub!(/^\s*\n/, "")
  File.write(t.name, content)

  puts "[xml_publish] #{File.basename(t.name)}"
end

desc xml_publish[:desc]
task :xml_publish => [:require_article, xml_publish[:out]]

# --- xml_to_output ---

xml_to_output = {
  in:   xml_publish[:out],
  out:  (OUTPUT_DIR / "xml/#{basename}.xml").to_s,
  desc: "Copy publishable XML to output",
}

file xml_to_output[:out] => [xml_to_output[:in]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  FileUtils.cp(t.source, t.name)
  puts "[xml_to_output] #{File.basename(t.name)}"
end

desc xml_to_output[:desc]
task :xml_to_output => [:require_article, xml_to_output[:out]]

# --- xml_to_refs ---
#
# OJS-Plain-Text-Referenzen: eine Referenz pro Zeile. Quelle ist das
# published XML (wie xml_to_output); jats2refs.xsl zieht pro <ref> die
# <mixed-citation> als reinen Text (method="text", <italic> fällt weg,
# normalize-space() kollabiert Serialisierungs-Umbrüche).

xml_to_refs = {
  in:      xml_publish[:out],
  out:     (BUILD_DIR / "refs/#{basename}-references.txt").to_s,
  tool:    CFG['xslt_cmd'],
  xsl:     (BUILD_DIR / '_assets/xslt/jats2refs.xsl').to_s,
  catalog: (BUILD_DIR / '_assets/jats-dtd/catalog-jats-v1-2-no-base.xml').to_s,
  desc:    "Extract references as plain text, one per line (OJS)",
}

file xml_to_refs[:out] => [xml_to_refs[:in], xml_to_refs[:xsl], xml_to_refs[:catalog]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  puts '[xml_to_refs] Extracting references to plain text...'

  cmd = [xml_to_refs[:tool],
         "-xsl:#{xml_to_refs[:xsl]}",
         "-catalog:#{xml_to_refs[:catalog]}",
         "-s:#{t.source}",
         "-o:#{t.name}"]

  stdout, stderr, status = Open3.capture3(*cmd)
  raise "XSLT refs extraction failed: #{stderr}" unless status.success?

  puts "[xml_to_refs] #{File.basename(t.name)}"
end

desc xml_to_refs[:desc]
task :xml_to_refs => [:require_article, xml_to_refs[:out]]

# --- refs_to_output ---

refs_to_output = {
  in:   xml_to_refs[:out],
  out:  (OUTPUT_DIR / "refs/#{basename}-references.txt").to_s,
  desc: "Copy references plain text to output",
}

file refs_to_output[:out] => [refs_to_output[:in]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  FileUtils.cp(t.source, t.name)
  puts "[refs_to_output] #{File.basename(t.name)}"
end

desc refs_to_output[:desc]
task :refs_to_output => [:require_article, refs_to_output[:out]]

# --- xml_to_zip ---
#
# Self-contained bundle: XML + die im XML referenzierten Web-Bilder
# (flach im ZIP-Root, damit xlink:href-Refs ohne Rewrite funktionieren) +
# Originale aus source/images/ in original-images/ (Beilage für Nachverwertung).
#
# Lade-Zeit-Fork: nur definiert wenn der Artikel Bilder hat. Ohne Bilder
# wäre der ZIP nur das XML — dann reicht das nackte xml_to_output-Output.

if image_targets.any?
  original_image_sources = RCB.load_manifest['sources']
    .select { |rel_path, _| image_exts.include?(File.extname(rel_path).downcase) }
    .map    { |rel_path, _| (BUILD_DIR / RCB::SOURCE_DIR / rel_path).to_s }

  xml_to_zip = {
    in:   [xml_publish[:out], *image_targets, *original_image_sources],
    out:  (OUTPUT_DIR / "xml/#{basename}.zip").to_s,
    tool:  CFG['zip_cmd'],
    desc: "Bundle XML + web images + originals into ZIP",
  }

  file xml_to_zip[:out] => xml_to_zip[:in] do |t|
    puts '[xml_to_zip] Staging files...'

    staging = BUILD_DIR / 'zip' / basename
    FileUtils.rm_rf(staging)
    FileUtils.mkdir_p(staging / 'original-images')

    FileUtils.cp(xml_publish[:out], staging / "#{basename}.xml")
    image_targets.each           { |img| FileUtils.cp(img, staging / File.basename(img)) }
    original_image_sources.each  { |img| FileUtils.cp(img, staging / 'original-images' / File.basename(img)) }

    FileUtils.mkdir_p(File.dirname(t.name))
    FileUtils.rm_f(t.name)  # sonst hängt zip ans existierende Archiv an
    abs_out = File.expand_path(t.name)
    _stdout, stderr, status = Open3.capture3(xml_to_zip[:tool], '-r', '-q', abs_out, '.', chdir: staging.to_s)
    raise "zip failed: #{stderr}" unless status.success?

    puts "[xml_to_zip] #{File.basename(t.name)}"
  end

  desc xml_to_zip[:desc]
  task :xml_to_zip => [xml_to_zip[:out]]
end

# ============================================
# HTML Pipeline
# ============================================

# --- xml_to_html ---

xml_to_html = {
  in:      xml_final[:out],
  out:     (BUILD_DIR / "html/#{basename}.html").to_s,
  tool:    CFG['xslt_cmd'],
  xsl:     (BUILD_DIR / '_assets/xslt/jats2html.xsl').to_s,
  catalog: (BUILD_DIR / '_assets/jats-dtd/catalog-jats-v1-2-no-base.xml').to_s,
  desc:    "Convert XML to HTML (Saxon)",
}

file xml_to_html[:out] => [xml_to_html[:in], xml_to_html[:xsl], xml_to_html[:catalog]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  puts '[xml_to_html] Converting XML to HTML...'

  cmd = [xml_to_html[:tool],
         "-xsl:#{xml_to_html[:xsl]}",
         "-catalog:#{xml_to_html[:catalog]}",
         "-s:#{t.source}",
         "-o:#{t.name}"]

  stdout, stderr, status = Open3.capture3(*cmd)
  raise "XSLT transformation failed: #{stderr}" unless status.success?

  puts "[xml_to_html] #{File.basename(t.name)}"
end

desc xml_to_html[:desc]
task :xml_to_html => [:require_article, xml_to_html[:out]]

# --- xml_to_html_test ---

xml_to_html_test = {
  in:      xml_final[:out],
  out:     (BUILD_DIR / "html/test-#{basename}.html").to_s,
  tool:    CFG['xslt_cmd'],
  xsl:     (BUILD_DIR / '_assets/xslt/jats2html.xsl').to_s,
  catalog: (BUILD_DIR / '_assets/jats-dtd/catalog-jats-v1-2-no-base.xml').to_s,
  css:     'galley.css',
  desc:    "Convert XML to HTML with CSS (Saxon)",
}

file xml_to_html_test[:out] => [xml_to_html_test[:in], xml_to_html_test[:xsl], xml_to_html_test[:catalog]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  puts '[xml_to_html_test] Converting XML to HTML with CSS...'

  cmd = [xml_to_html_test[:tool],
         "-xsl:#{xml_to_html_test[:xsl]}",
         "-catalog:#{xml_to_html_test[:catalog]}",
         "-s:#{t.source}",
         "-o:#{t.name}",
         "stylesheet=#{xml_to_html_test[:css]}"]

  stdout, stderr, status = Open3.capture3(*cmd)
  raise "XSLT transformation failed: #{stderr}" unless status.success?

  puts "[xml_to_html_test] #{File.basename(t.name)} (with CSS)"
end

desc xml_to_html_test[:desc]
task :xml_to_html_test => [:require_article, xml_to_html_test[:out]]

# --- html_to_output ---

html_to_output = {
  in:   xml_to_html[:out],
  out:  (OUTPUT_DIR / "html/#{basename}.html").to_s,
  desc: "Copy HTML to output",
}

file html_to_output[:out] => [html_to_output[:in]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  FileUtils.cp(t.source, t.name)
  puts "[html_to_output] #{File.basename(t.name)}"
end

desc html_to_output[:desc]
task :html_to_output => [:require_article, html_to_output[:out]]

# --- html_test_to_output ---

html_test_to_output = {
  in:      xml_to_html_test[:out],
  out:     (OUTPUT_DIR / "html/test-#{basename}.html").to_s,
  css_src: (BUILD_DIR / '_assets/css/galley.css').to_s,
  css_dst: (OUTPUT_DIR / 'html/galley.css').to_s,
  desc:    "Copy test HTML + CSS to output",
}

file html_test_to_output[:out] => [html_test_to_output[:in], html_test_to_output[:css_src]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  FileUtils.cp(t.source, t.name)
  FileUtils.cp(html_test_to_output[:css_src], html_test_to_output[:css_dst])
  puts "[html_test_to_output] #{File.basename(t.name)} + galley.css"
end

desc html_test_to_output[:desc]
task :html_test_to_output => [:require_article, html_test_to_output[:out]]

# ============================================
# PDF Pipeline
# ============================================

# --- xml_to_pdf ---

# Load-Zeit: Module context/_*.tex aus dem Manifest → file-deps, damit
# Modul-Edit einen PDF-Rebuild triggert (gleiche Mechanik wie sch_source_files).
# Override-aware: ein Journal-/Artikel-Modul taucht in manifest['assets'] auf.
context_modules = RCB.load_manifest['assets'].keys
  .select { |k| k =~ %r{^context/_.*\.tex$} }
  .map    { |k| (BUILD_DIR / RCB::ASSETS_DIR / k).to_s }
  .sort

xml_to_pdf = {
  in:      xml_final[:out],
  out:     (BUILD_DIR / "pdf/#{basename}.pdf").to_s,
  tool:    CFG['context_cmd'],
  jats:    (BUILD_DIR / '_assets/context/jats.tex').to_s,
  layout:  (BUILD_DIR / '_assets/context/layout.tex').to_s,
  mode:    CFG['context_mode'] || 'article',
  imgdir:  (BUILD_DIR / CFG['image_web_dir']).to_s,
  desc:    "Convert XML to PDF (ConTeXt)",
}

file xml_to_pdf[:out] => [xml_to_pdf[:in], xml_to_pdf[:jats], xml_to_pdf[:layout], *context_modules, *image_targets] do |t|
  puts '[xml_to_pdf] Converting XML to PDF...'

  pdf_dir = File.dirname(t.name)
  FileUtils.mkdir_p(pdf_dir)

  # ConTeXt needs relative paths from pdf dir
  xml_rel = File.join('..', 'xml', File.basename(t.source))
  assets_rel = File.join('..', '_assets')
  # nonumheadings jointly aus CFG (gleiche Quelle wie Morgana-Option im
  # xml_clean-Step): Mode aktiviert layout.tex \startmode[nonumheadings]
  # -> \setuphead[…][number=no]. mode ist komma-separiert, Anhaengen safe.
  mode = xml_to_pdf[:mode]
  mode = "#{mode},nonumheadings" if CFG['nonumheadings']

  cmd = [xml_to_pdf[:tool],
         xml_rel,
         "--environment=#{assets_rel}/context/jats.tex,#{assets_rel}/context/layout.tex",
         "--mode=#{mode}",
         "--imagedir=#{File.join('..', CFG['image_web_dir'])}",
         "--result=#{File.basename(t.name)}"]

  stdout, stderr, status = Open3.capture3(*cmd, chdir: pdf_dir)
  raise "ConTeXt conversion failed: #{stderr}" unless status.success?

  puts "[xml_to_pdf] #{File.basename(t.name)}"
end

desc xml_to_pdf[:desc]
task :xml_to_pdf => [:require_article, :convert_images, xml_to_pdf[:out]]

# --- pdf_to_output ---

pdf_to_output = {
  in:   xml_to_pdf[:out],
  out:  (OUTPUT_DIR / "pdf/#{basename}.pdf").to_s,
  desc: "Copy PDF to output",
}

file pdf_to_output[:out] => [pdf_to_output[:in]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  FileUtils.cp(t.source, t.name)
  puts "[pdf_to_output] #{File.basename(t.name)}"
end

desc pdf_to_output[:desc]
task :pdf_to_output => [:require_article, pdf_to_output[:out]]

# --- xml_to_pdf_test ---

xml_to_pdf_test = {
  in:      xml_final[:out],
  out:     (BUILD_DIR / "pdf/#{basename}-test.pdf").to_s,
  tool:    CFG['context_cmd'],
  mode:    CFG['context_mode'] || 'article',
  desc:    "Convert XML to test PDF (ConTeXt)",
}

file xml_to_pdf_test[:out] => [xml_to_pdf_test[:in], xml_to_pdf[:jats], xml_to_pdf[:layout], *context_modules, *image_targets] do |t|
  puts '[xml_to_pdf_test] Converting XML to test PDF...'

  pdf_dir = File.dirname(t.name)
  FileUtils.mkdir_p(pdf_dir)

  xml_rel = File.join('..', 'xml', File.basename(t.source))
  assets_rel = File.join('..', '_assets')
  mode = xml_to_pdf_test[:mode]
  mode = "#{mode},nonumheadings" if CFG['nonumheadings']

  cmd = [xml_to_pdf_test[:tool],
         xml_rel,
         "--environment=#{assets_rel}/context/jats.tex,#{assets_rel}/context/layout.tex",
         "--mode=#{mode}",
         "--imagedir=#{File.join('..', CFG['image_web_dir'])}",
         "--result=#{File.basename(t.name)}"]

  stdout, stderr, status = Open3.capture3(*cmd, chdir: pdf_dir)
  raise "ConTeXt conversion failed: #{stderr}" unless status.success?

  puts "[xml_to_pdf_test] #{File.basename(t.name)}"
end

desc xml_to_pdf_test[:desc]
task :xml_to_pdf_test => [:require_article, :convert_images, xml_to_pdf_test[:out]]

# --- pdf_test_to_output ---

pdf_test_to_output = {
  in:   xml_to_pdf_test[:out],
  out:  (OUTPUT_DIR / "pdf/#{basename}-test.pdf").to_s,
  desc: "Copy test PDF to output",
}

file pdf_test_to_output[:out] => [pdf_test_to_output[:in]] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  FileUtils.cp(t.source, t.name)
  puts "[pdf_test_to_output] #{File.basename(t.name)}"
end

desc pdf_test_to_output[:desc]
task :pdf_test_to_output => [:require_article, pdf_test_to_output[:out]]

# ============================================
# Build All
# ============================================

desc "Build publishable outputs (XML, HTML, PDF, images)"
task :build_publish => [:require_article, :setup_build, :setup_output, :prepare_assets, :xml_to_output, :html_to_output, :pdf_to_output, :images_to_output, :refs_to_output]

desc "Build test outputs (XML, test HTML with CSS, test PDF, images)"
task :build_test => [:require_article, :setup_build, :setup_output, :prepare_assets, :xml_to_output, :html_test_to_output, :pdf_test_to_output, :images_to_output]

desc "Build everything (publish + test)"
task :build_all => [:require_article, :build_publish, :build_test]

# ============================================
# Scaffold Tasks
# ============================================

desc "Initialize a new article directory (run from volume level)"
task :init_article do
  # Read journal metadata (parent directory)
  journal_md_file = Pathname.pwd.parent / 'metadata.yaml'
  unless journal_md_file.exist?
    raise "No journal metadata.yaml found at #{journal_md_file}\n  Are you in a volume directory?"
  end
  journal_md = YAML.load_file(journal_md_file)
  abbrev = (journal_md.dig('journal', 'abbrev-title') || 'journal').downcase

  # Read volume metadata (current directory)
  volume_md_file = Pathname.pwd / 'metadata.yaml'
  unless volume_md_file.exist?
    raise "No volume metadata.yaml found at #{volume_md_file}\n  Are you in a volume directory?"
  end
  volume_md = YAML.load_file(volume_md_file)
  year = volume_md.dig('date', 'year') || Time.now.year

  # Suggest next article number from existing directories
  existing = Pathname.pwd.children.select(&:directory?).reject { |d| d.basename.to_s.start_with?('.') }
  next_num = existing.count + 1

  puts "=== New Article ==="
  puts ""

  # Article number
  print "Article number [#{next_num}]: "
  input = $stdin.gets.chomp
  num = input.empty? ? next_num : input.to_i

  # Author last name
  print "Author last name: "
  author_name = $stdin.gets.chomp
  if author_name.empty?
    raise "Author last name is required"
  end
  author_slug = author_name.downcase.gsub(/\s+/, '-')

  # Construct basename (= directory name)
  basename = "#{abbrev}-#{year}-#{num}-#{author_slug}"

  puts ""
  puts "  #{basename}/"
  puts "    rcb.rake"
  puts "    metadata.yaml"
  puts "    source/"
  puts "      images/"
  puts ""
  print "OK? [Y/n]: "
  confirm = $stdin.gets.chomp
  unless confirm.empty? || confirm.downcase == 'y'
    puts "Aborted."
    next
  end

  # Create directory structure
  article_dir = Pathname.pwd / basename
  raise "Directory already exists: #{article_dir}" if article_dir.exist?

  article_dir.mkpath
  (article_dir / 'source').mkpath
  (article_dir / 'source' / 'images').mkpath

  # Write rcb.config.rb (build-config — loaded before rcb.rake)
  File.write(article_dir / 'rcb.config.rb', <<~RUBY)
    # rcb.config.rb - Article-level build config

    CFG['basename']      = '#{basename}'
    CFG['source_format'] = 'docx'
  RUBY

  # Write rcb.rake (tasks only — Inhalts-Metadaten kommen aus metadata.yaml)
  File.write(article_dir / 'rcb.rake', <<~RUBY)
    # rcb.rake - Article-level tasks

    desc "Show full article info (reads from metadata.yaml, shows merged view)"
    task :full_article_info do
      all_md = {}
      ($rcb_cascade_dirs || []).reverse.each do |level_dir|
        md_file = Pathname.new(level_dir) / 'metadata.yaml'
        next unless md_file.exist?
        level_md = YAML.load_file(md_file) || {}
        all_md = deep_merge(all_md, level_md)
      end

      puts "=== Article Info (merged from cascade) ==="
      article = all_md['article'] || {}
      puts "Title: \#{article['title'] || all_md['title'] || '(not set)'}"
      puts "Type: \#{article['type'] || '(not set)'}"
      puts "Language: \#{article['lang'] || '(not set)'}"
      puts "DOI Article Number: \#{article['doi_article_number'] || '(not set)'}"

      authors = all_md['author'] || []
      if authors.any?
        puts "Authors:"
        authors.each { |a| puts "  - \#{a['given-names']} \#{a['surname']} (\#{a['affiliation']})" }
      else
        puts "Authors: (none)"
      end

      puts "Volume: \#{article['volume'] || '(not set)'}"
      date = all_md['date'] || {}
      puts "Year: \#{date['year'] || '(not set)'}"

      journal = all_md['journal'] || {}
      puts "Journal: \#{journal['title'] || '(not set)'}"
      puts "eISSN: \#{journal['eissn'] || '(not set)'}"

      puts ""
      puts "=== Build Config ==="
      puts "Basename: \#{CFG['basename']}"
      puts "Source Format: \#{CFG['source_format']}"
    end

    def deep_merge(base, override)
      base.merge(override) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end
  RUBY

  # Copy metadata template from assets
  template_file = nil
  ($rcb_cascade_dirs || [Pathname.pwd]).each do |dir|
    candidate = Pathname.new(dir) / '_assets' / 'metadata' / 'metadata-template-article.yaml'
    if candidate.exist?
      template_file = candidate
      break
    end
  end

  if template_file
    content = File.read(template_file)
    # Fill in known values
    content.gsub!('surname: "???"', "surname: \"#{author_name}\"")
    # Add doi_article_number to existing article: block
    content.sub!(/^article:\n  type:/, "article:\n  doi_article_number: #{num}\n  type:")
    File.write(article_dir / 'metadata.yaml', content)
  else
    puts "WARNING: metadata template not found, creating minimal metadata.yaml"
    File.write(article_dir / 'metadata.yaml', <<~YAML)
      ---
      article:
        doi_article_number: #{num}
      author:
      - surname: "#{author_name}"
        given-names: "???"
        affiliation: "???"
    YAML
  end

  puts ""
  puts "Created: #{basename}/"
  puts ""
  puts "Next:"
  puts "  1. cp your-file.docx #{basename}/source/#{basename}.docx"
  puts "  2. cd #{basename}/"
  puts "  3. rcb-dev extract_metadata"
end

# ============================================
# Default task
# ============================================

task :default => [:validate_config] do
  puts "Run 'rcb-dev list' to see all available tasks"
end

# ============================================
# Info Task
# ============================================

desc "Show article info"
task :article_info do
  puts "Article Info:"
  puts "  Publisher: #{CFG['publisher_name']}"
  puts "  Build dir: #{CFG['build_dir']}"
  puts "  Output dir: #{CFG['output_dir']}"
end
