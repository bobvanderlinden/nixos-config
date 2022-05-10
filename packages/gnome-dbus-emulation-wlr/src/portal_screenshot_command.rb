require 'dbus'
require 'fileutils'
require 'uri'
require_relative './portal_screenshot'

class PortalScreenshotCommand
  def call(filename, cursor:, flash:)
    success = false

    PortalScreenshot.new.screenshot do |response|
      path = URI.parse(response.uri).path
      FileUtils.mv(path, filename)
      success = true
    rescue DBus::Error
      puts 'Portal not running'
    end

    success
  end
end

