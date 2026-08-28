# rcb.rake - Volume level configuration
# Nur Build-Verhalten in CFG, Inhalts-Metadaten kommen aus metadata.yaml

# Keine volume-spezifische Build-Config aktuell

desc "Show volume info (reads from metadata.yaml)"
task :volume_info do
  md_file = Pathname.new(__dir__) / 'metadata.yaml'

  unless md_file.exist?
    puts "No metadata.yaml found at #{md_file}"
    return
  end

  md = YAML.load_file(md_file)
  article = md['article'] || {}
  date = md['date'] || {}

  puts "=== Volume Info ==="
  puts "Volume: #{article['volume'] || '(not set)'}"
  puts "Year: #{date['year'] || '(not set)'}"

  # Zeige auch geerbte Journal-Info (Parent level)
  journal_md_file = Pathname.new(__dir__).parent / 'metadata.yaml'
  if journal_md_file.exist?
    journal_md = YAML.load_file(journal_md_file)
    journal = journal_md['journal'] || {}
    puts "Journal: #{journal['title'] || '(not set)'}"
  end
end