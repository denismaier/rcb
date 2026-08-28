# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/rcb'
require 'tmpdir'
require 'fileutils'
require 'yaml'

# Setup für globalen State — leert WARNINGS vor jedem Test
class Minitest::Test
  def setup
    RCB::WARNINGS.clear
  end
end
