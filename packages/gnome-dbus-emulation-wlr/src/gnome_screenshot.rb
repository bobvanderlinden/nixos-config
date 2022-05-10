#!/usr/bin/env ruby

require 'dbus'

class GnomeScreenshot
  SERVICE_NAME = 'org.gnome.Shell.Screenshot'
  OBJECT_NAME = '/org/gnome/Shell/Screenshot'

  def initialize(bus: DBus.session_bus)
    @bus = bus
  end

  def running
    gnomeshot_service = @bus.service(SERVICE_NAME)
    gnomeshot_service.object(OBJECT_NAME)
  end

  def screenshot(filename, include_cursor: true, flash: false)
    running[SERVICE_NAME].Screenshot(include_cursor, flash, filename)
  end
end

# Usage: `ruby gnome_screenshot.rb` to open with default viewer
# Usage: `ruby gnome_screenshot.rb screenshot-destination.png`
if __FILE__ == $0
  begin
    filename = ARGV.first || 'screenshot.png'
    path = filename.include?('/') ? path : File.join(Dir.pwd, filename)
    GnomeScreenshot.new.screenshot(path)
    system('xdg-open', path) unless ARGV.first
  end
end
