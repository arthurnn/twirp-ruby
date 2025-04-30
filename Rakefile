#!/usr/bin/env rake
require "bundler/gem_helper"
require "rake/testtask"

# Override Bundler's gem release tasks to use the new tag format
class CustomGemHelper < Bundler::GemHelper
  def version_tag
    "ruby-v#{version}"
  end
end

# Replace the standard gem tasks with our custom implementation
CustomGemHelper.install_tasks

Rake::TestTask.new do |t|
  t.test_files = FileList['test/*_test.rb']
  t.warning = false
end

task :default => :test
