# rcb.rake - Journal level configuration
# Nur Build-Verhalten in CFG, Inhalts-Metadaten kommen aus metadata.yaml

# Keine journal-spezifische Build-Config aktuell

desc "Show journal info (reads from metadata.yaml)"
task :journal_info do
  md_file = Pathname.new(__dir__) / 'metadata.yaml'

  unless md_file.exist?
    puts "No metadata.yaml found at #{md_file}"
    return
  end

  md = YAML.load_file(md_file)
  journal = md['journal'] || {}

  puts "=== Journal Info ==="
  puts "Title: #{journal['title'] || '(not set)'}"
  puts "Publisher ID: #{journal['publisher-id'] || '(not set)'}"
  puts "Abbrev: #{journal['abbrev-title'] || '(not set)'}"
  puts "eISSN: #{journal['eissn'] || '(not set)'}"
  puts "DOI Prefix: #{journal['doi_prefix'] || '(not set)'}"
end
