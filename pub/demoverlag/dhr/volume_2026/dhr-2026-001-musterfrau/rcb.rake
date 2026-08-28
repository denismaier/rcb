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
  puts "Title: #{article['title'] || all_md['title'] || '(not set)'}"
  puts "Type: #{article['type'] || '(not set)'}"
  puts "Language: #{article['lang'] || '(not set)'}"
  puts "DOI Article Number: #{article['doi_article_number'] || '(not set)'}"

  authors = all_md['author'] || []
  if authors.any?
    puts "Authors:"
    authors.each { |a| puts "  - #{a['given-names']} #{a['surname']} (#{a['affiliation']})" }
  else
    puts "Authors: (none)"
  end

  puts "Volume: #{article['volume'] || '(not set)'}"
  date = all_md['date'] || {}
  puts "Year: #{date['year'] || '(not set)'}"

  journal = all_md['journal'] || {}
  puts "Journal: #{journal['title'] || '(not set)'}"
  puts "eISSN: #{journal['eissn'] || '(not set)'}"

  puts ""
  puts "=== Build Config ==="
  puts "Basename: #{CFG['basename']}"
  puts "Source Format: #{CFG['source_format']}"
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