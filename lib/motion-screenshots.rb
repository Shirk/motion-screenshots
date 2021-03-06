unless defined?(Motion::Project::Config)
  raise "This file must be required within a RubyMotion project Rakefile."
end

require 'motion-cocoapods'
require 'motion-env'
require 'fileutils'
require 'shellwords'

lib_dir_path = File.dirname(File.expand_path(__FILE__))
Motion::Project::App.setup do |app|
  gem_files = Dir.glob(File.join(lib_dir_path, "motion/**/*.rb"))
  app.files.unshift(gem_files).flatten!
end

module Motion; module Project; class Config
  attr_accessor :screenshot_callback, :is_taking_screenshots

  variable :screenshots_output_path

  def before_screenshots(&block)
    if is_taking_screenshots
      block.call
    end
  end

  def after_screenshots(&block)
    @screenshot_callback = block
  end

  alias_method :manage_screenshots, :after_screenshots
end; end; end

namespace 'screenshots' do
  task :start do
    app_config = Motion::Project::App.config_without_setup
    app_config.pods do
      pod 'KSScreenshotManager'
    end

    app_config.is_taking_screenshots = true
    app_config.env['MOTION_SCREENSHOTS_RUNNING'] = true

    if app_config.archs['iPhoneSimulator'].include? 'x86_64'
      # required until KSScreenshotManager is 64bit compatible
      App.warn 'Forcing 32bit-only build target for screenshots..'
      app_config.archs['iPhoneSimulator'] = %w(i386)
    end

    screenshots_output_path = ENV['SCREENSHOTS_DIR']
    screenshots_output_path ||= App.config.screenshots_output_path
    screenshots_output_path ||= File.join(`pwd`.strip, "screenshots", Time.now.to_i.to_s)
    FileUtils.mkdir_p screenshots_output_path

    at_exit {
      # Copy files
      target = ENV['target'] || app_config.sdk_version
      sim_apps = File.expand_path("~/Library/Application Support/iPhone Simulator/*/Applications")
      app_dir = nil
      app = app_config.app_bundle('iPhoneSimulator')
      app_dir = File.dirname(Dir.glob("#{sim_apps}/**/#{File.basename(app)}").sort_by { |f|
        File.mtime(f)
      }.reverse.first)
      motion_screenshots = File.join(app_dir, "Documents", "motion_screenshots")
      screenshot_files = Dir[File.join(motion_screenshots, "**", "*")]
      FileUtils.cp_r(screenshot_files, screenshots_output_path)
      if app_config.screenshot_callback
        app_config.screenshot_callback.call(screenshots_output_path)
      else
        `open #{screenshots_output_path.shellescape}`
      end
      puts "Re-installing pods..."
      `bundle exec rake pod:install`
    }

    Rake::Task["pod:install"].invoke
    Rake::Task["default"].invoke
  end
end

desc "Take screenshots in your app"
task :screenshots => "screenshots:start"