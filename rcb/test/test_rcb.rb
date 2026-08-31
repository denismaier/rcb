# frozen_string_literal: true

require_relative 'test_helper'

class TestRCB < Minitest::Test
  # --- test_find_cascade ---

  def test_find_cascade_walks_up_to_rcbroot
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "journal", "article"))
      File.write(File.join(tmp, ".rcbroot"), "")
      File.write(File.join(tmp, "rcb.rake"), "")
      File.write(File.join(tmp, "journal", "rcb.rake"), "")

      root, rakefiles, cascade_dirs = RCB.find_cascade(Pathname.new(File.join(tmp, "journal", "article")))

      assert_equal 2, rakefiles.length  # root + journal level
      assert_match(/\/rcb\.rake$/, rakefiles.first.to_s)  # root first
      assert_equal 3, cascade_dirs.length  # article, journal, tmp (root)
      assert_match(/article$/, cascade_dirs.first.to_s)  # start_dir is first
      assert Pathname.new(tmp).expand_path.to_s.include?(cascade_dirs.last)  # root is last
      assert Pathname.new(tmp).expand_path.to_s.include?(root.to_s)
    end
  end

  def test_find_cascade_finds_rcbroot_at_start_dir
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, ".rcbroot"), "")
      File.write(File.join(tmp, "rcb.rake"), "")

      root, rakefiles, cascade_dirs = RCB.find_cascade(Pathname.new(tmp))

      assert_equal 1, rakefiles.length
      assert_equal 1, cascade_dirs.length
      assert Pathname.new(tmp).expand_path.to_s.include?(root.to_s)
    end
  end

  def test_find_cascade_raises_error_without_rcbroot
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "subdir"))

      assert_raises(SystemExit) do
        RCB.find_cascade(Pathname.new(File.join(tmp, "subdir")))
      end
    end
  end

  # --- test_scan_assets ---

  def test_scan_assets_collects_files_from_levels
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p("#{tmp}/level1/_assets")
      FileUtils.mkdir_p("#{tmp}/level2/_assets")
      File.write("#{tmp}/level1/_assets/a.txt", "level1")
      File.write("#{tmp}/level2/_assets/b.txt", "level2")
      File.write("#{tmp}/level2/_assets/a.txt", "level2_a")  # shadowing

      dirs = ["#{tmp}/level1", "#{tmp}/level2"]
      result = RCB.scan_assets(dirs, "_assets")

      assert_equal 2, result.keys.length
      assert_equal "#{tmp}/level2/_assets/a.txt", result["a.txt"]
      assert_equal "#{tmp}/level2/_assets/b.txt", result["b.txt"]
    end
  end

  def test_scan_assets_returns_empty_hash_without_assets_dirs
    Dir.mktmpdir do |tmp|
      dirs = [tmp]
      result = RCB.scan_assets(dirs, "_assets")

      assert_equal({}, result)
    end
  end

  def test_scan_assets_ignores_dotfiles
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p("#{tmp}/_assets")
      File.write("#{tmp}/_assets/.hidden", "hidden")
      File.write("#{tmp}/_assets/visible.txt", "visible")

      result = RCB.scan_assets([tmp], "_assets")

      assert_equal 1, result.keys.length
      assert result.key?("visible.txt")
      refute result.key?(".hidden")
    end
  end

  # --- test_scan_source ---

  def test_scan_source_collects_source_files
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p("#{tmp}/source/subdir")
      File.write("#{tmp}/source/main.md", "content")
      File.write("#{tmp}/source/subdir/extra.md", "more")
      File.write("#{tmp}/source/.hidden", "hidden")
      File.write("#{tmp}/source/file.bak", "backup")

      result = RCB.scan_source(Pathname.new(tmp))

      # 2 Dateien: main.md und subdir/extra.md (ohne .hidden und .bak)
      assert_equal 2, result.keys.length
      assert result.key?("main.md")
      assert result.key?("subdir/extra.md")
      refute result.key?(".hidden")
      refute result.key?("file.bak")
    end
  end

  def test_scan_source_includes_images_in_source_images
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p("#{tmp}/source/images")
      File.write("#{tmp}/source/images/logo.png", "png_content")

      result = RCB.scan_source(Pathname.new(tmp))

      assert result.key?("images/logo.png")
    end
  end

  def test_scan_source_returns_empty_hash_without_source_dir
    Dir.mktmpdir do |tmp|
      result = RCB.scan_source(Pathname.new(tmp))

      assert_equal({}, result)
    end
  end

  # --- test_scan_metadata ---

  def test_scan_metadata_finds_metadata_yaml
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p("#{tmp}/level1")
      FileUtils.mkdir_p("#{tmp}/level2")
      File.write("#{tmp}/level1/metadata.yaml", "title: level1")
      File.write("#{tmp}/level2/metadata.yaml", "title: level2")

      result = RCB.scan_metadata(["#{tmp}/level1", "#{tmp}/level2"])

      assert_equal 2, result.length
      assert_match(/level1/, result.first)
      assert_match(/level2/, result.last)
    end
  end

  def test_scan_metadata_skips_levels_without_metadata
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p("#{tmp}/level1")
      File.write("#{tmp}/level1/metadata.yaml", "title: level1")

      result = RCB.scan_metadata(["#{tmp}/level1", "#{tmp}/level2"])

      assert_equal 1, result.length
      assert_match(/level1/, result.first)
    end
  end

  # --- test_scan_configs ---

  def test_scan_configs_finds_rcb_config_rb
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p("#{tmp}/level1")
      FileUtils.mkdir_p("#{tmp}/level2")
      File.write("#{tmp}/level1/rcb.config.rb", "# config1")
      File.write("#{tmp}/level2/rcb.config.rb", "# config2")

      result = RCB.scan_configs(["#{tmp}/level1", "#{tmp}/level2"])

      assert_equal 2, result.length
      assert_match(/level1/, result.first)
      assert_match(/level2/, result.last)
    end
  end

  # --- test_load_manifest ---

  # load_manifest ist nur ein Wrapper um YAML.load_file(MANIFEST_PATH).
  # MANIFEST_PATH ist eine Konstante — für die Test-Fixture wird sie
  # temporär auf eine tmp-Datei umgebogen und danach restauriert.
  def test_load_manifest_loads_existing_manifest
    original_path = RCB::MANIFEST_PATH
    Dir.mktmpdir do |tmp|
      manifest_path = Pathname.new(tmp) / "manifest.yaml"
      File.write(manifest_path, {
        "cascade"  => [],
        "configs"  => [],
        "assets"   => {},
        "sources"  => {},
        "metadata" => [],
      }.to_yaml)

      RCB.send(:remove_const, :MANIFEST_PATH)
      RCB.const_set(:MANIFEST_PATH, manifest_path)

      result = RCB.load_manifest
      assert_instance_of(Hash, result)
      assert result.key?("cascade")
    end
  ensure
    if RCB.const_defined?(:MANIFEST_PATH) && RCB::MANIFEST_PATH != original_path
      RCB.send(:remove_const, :MANIFEST_PATH)
      RCB.const_set(:MANIFEST_PATH, original_path)
    end
  end

  # --- test_ensure_dirs ---

  def test_ensure_dirs_creates_missing_dirs
    Dir.mktmpdir do |tmp|
      new_dir = "#{tmp}/new_dir"

      RCB.ensure_dirs([new_dir])

      assert File.directory?(new_dir)
    end
  end

  def test_ensure_dirs_leaves_existing_dirs_untouched
    Dir.mktmpdir do |tmp|
      existing = "#{tmp}/existing"
      FileUtils.mkdir_p(existing)
      File.write("#{existing}/file.txt", "content")

      RCB.ensure_dirs([existing])

      assert File.file?("#{existing}/file.txt")
    end
  end

  # --- test_warn ---

  def test_warn_appends_to_warnings
    RCB.warn("first warning")
    RCB.warn("second warning")

    assert_equal 2, RCB::WARNINGS.length
    assert_includes RCB::WARNINGS, "first warning"
    assert_includes RCB::WARNINGS, "second warning"
  end
end
