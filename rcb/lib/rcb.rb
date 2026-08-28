# frozen_string_literal: true

require_relative "rcb/version"
require "optparse"
require "rake"
require "pathname"
require 'fileutils'
require 'find'
require 'yaml'
include Rake::DSL

# Shared build configuration, populated by rcb.config.rb files across the cascade.
# Defined at toplevel so all rcb.rake files see it without qualification.
CFG = {}

# RCB - Ruby Cascade Build
# Simplified cascading build system using Rake
module RCB
  class Error < StandardError; end

   BUILD_DIR = Pathname.new('.build')
   ASSETS_DIR = Pathname.new('_assets')
   SOURCE_DIR = Pathname.new('source')
   METADATA_FILE = 'metadata.yaml'
   MANIFEST_PATH = BUILD_DIR / 'manifest.yaml'

  # Deferred warnings — collected during the build, summarised at process exit.
  # Use RCB.warn(msg) to add. Non-fatal, visible as last thing on the terminal.
  WARNINGS = []

  def self.warn(message)
    WARNINGS << message
  end

  def self.ensure_dirs(dirs)
    dirs.each do |dir|
      unless File.directory?(dir)
        FileUtils.mkdir_p(dir)
      end
    end
  end

  def self.find_cascade(start_dir)

    # Find .rcbroot
    root = start_dir.ascend { |dir| break dir if (dir + '.rcbroot').exist? }
    unless root
      $stderr.puts "\n⚠️  Error: Not in an RCB project"
      $stderr.puts "   Navigate to a directory within the cascade (e.g., publisher/, journal/, or article/)"
      $stderr.puts "   Current directory: #{Pathname.pwd}"
      exit 1
    end

    # Collect rcb.rake files (root-first) AND cascade directories
    rakefiles = []
    cascade_dirs = []
    current = start_dir

    loop do
      file = current + 'rcb.rake'
      rakefiles << file if file.exist?
      cascade_dirs << current.to_s  # Add to cascade for CFG
      break if current == root
      current = current.parent
    end

    rakefiles.reverse!

    [root, rakefiles, cascade_dirs]
  
  end

  def self.scan_assets(dirs, assets_dir_name)
    # Collect files from all cascade levels (shadowing: last wins)
    files_to_copy = {}

    (dirs || []).each do |level_dir|
      level_assets = Pathname.new(level_dir) / assets_dir_name
      next unless level_assets.exist?

      level_assets.find do |file|
        next if file.directory?
        next if file.basename.to_s.start_with?('.')

        rel_path = file.relative_path_from(level_assets)
        files_to_copy[rel_path.to_s] = file.to_s  
      end
    end
    files_to_copy
  end

  def self.scan_source(article_dir)
    source_root = Pathname.new(article_dir) / SOURCE_DIR
    return {} unless source_root.exist?

    files = {}
    source_root.find do |path|
      next if path.directory?
      basename = path.basename.to_s
      next if basename.start_with?('.')
      next if basename.end_with?('.bak')

      rel = path.relative_path_from(source_root).to_s
      files[rel] = path.to_s
    end
    files
  end

  def self.scan_metadata(cascade_dirs)
    (cascade_dirs || []).filter_map do |dir|
      md = Pathname.new(dir) / METADATA_FILE
      md.to_s if md.exist?
    end
  end

  def self.scan_configs(cascade_dirs)
    (cascade_dirs || []).filter_map do |dir|
      cf = Pathname.new(dir) / 'rcb.config.rb'
      cf.to_s if cf.exist?
    end
  end

  def self.load_manifest
    YAML.load_file(MANIFEST_PATH)
  end


  def self.generate_asset_file_tasks(assets)
    targets = []
    assets.each do |rel_path, origin|
      target = (BUILD_DIR / ASSETS_DIR / rel_path).to_s
      targets << target

      Rake::FileTask.define_task(target => [origin]) do |t|
        FileUtils.mkdir_p(File.dirname(t.name))
        FileUtils.cp(t.source, t.name)
        puts "[asset] Copy #{File.basename(t.name)}"
      end
    end
    targets
  end

  def self.generate_source_file_tasks(sources)
    targets = []
    sources.each do |rel_path, origin|
      target = (BUILD_DIR / SOURCE_DIR / rel_path).to_s
      targets << target

      Rake::FileTask.define_task(target => [origin]) do |t|
        FileUtils.mkdir_p(File.dirname(t.name))
        FileUtils.cp(t.source, t.name)
        puts "[source] Copy #{File.basename(t.name)}"
      end
    end
    targets
  end

  # Main entry point - called from exe/rcb
  def self.run(options, args)
    # Set global options for tasks to access
    $rcb_options = options

    root, rakefiles, cascade_dirs = find_cascade(Pathname.pwd)

    ensure_dirs([BUILD_DIR])

    # Set cascade_dirs before loading rakefiles so they (and the scanners) can use it
    # Root-first order: publisher → journal → volume → article
    $rcb_cascade_dirs = cascade_dirs.reverse.freeze

    # Load configs first (root-first) — mutates CFG, so rakefiles see fully-populated CFG at load time
    scan_configs($rcb_cascade_dirs).each { |cf| load cf }

    # Scan cascade for resources (no CFG needed — pure filesystem)
    assets   = scan_assets($rcb_cascade_dirs, ASSETS_DIR)
    sources  = scan_source($rcb_cascade_dirs.last)
    metadata = scan_metadata($rcb_cascade_dirs)

    # Write manifest BEFORE loading rakefiles so they can RCB.load_manifest at definition time
    manifest = {
      'cascade'  => $rcb_cascade_dirs.to_a,
      'config'   => CFG.to_h,
      'assets'   => assets,
      'sources'  => sources,
      'metadata' => metadata,
    }
    File.write(MANIFEST_PATH, manifest.to_yaml)

    # Load Rakefiles (CFG gets populated, pipeline tasks get defined)
    puts "[DEBUG] rcb.rake files to load:" if options[:debug]
    rakefiles.each { |rf| puts "[DEBUG]   #{rf}" if options[:debug] }
    rakefiles.each { |rf| load rf }

    # Register generic alias tasks for assets and sources (file tasks already defined via generators)
    asset_targets = generate_asset_file_tasks(assets)
    Rake::Task.define_task(:prepare_assets => asset_targets) do
      puts "[prepare_assets] #{asset_targets.size} assets ready"
    end

    source_targets = generate_source_file_tasks(sources)
    Rake::Task.define_task(:copy_source => source_targets) do
      puts "[copy_source] #{source_targets.size} source files ready"
    end

    # Handle commands
    task_name = args[0]

    # Special command: list (or no task = list)
    if task_name.nil? || task_name == 'list'
      puts "RCB Tasks (#{Rake.application.tasks.size}):"
      Rake.application.tasks.each { |t| puts "  #{t.name.ljust(25)} #{t.comment}" }
      exit 0
    end

    # Check if task exists before invoking
    begin
      task = Rake.application[task_name]
    rescue RuntimeError => e
      # Task doesn't exist
      $stderr.puts "\n⚠️  Error: Unknown task '#{task_name}'"
      $stderr.puts "   Run 'rcb list' to see all available tasks"
      exit 1
    end

    # Run Rake with the specified task
    task.invoke
  end
end

at_exit do
  if RCB::WARNINGS.any?
    puts "\n" + "=" * 70
    puts "BUILD WARNINGS (#{RCB::WARNINGS.size}):"
    RCB::WARNINGS.each { |w| puts "  ⚠  #{w}" }
    puts "=" * 70
  end
end
