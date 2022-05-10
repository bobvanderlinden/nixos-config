#!/usr/bin/env ruby

require 'dbus'
require_relative './emulate_gnome_screenshot'
require_relative './custom_screenshot_command'

class GnomeDBusEmulation
  def initialize(bus: DBus.session_bus)
    @bus = bus
  end

  def run!(screenshot_command: nil)
    register_additional_services

    EmulateGnomeScreenshot.new(bus: @bus, command: screenshot_command).run!
  end

  def register_additional_services
    session_manager = @bus.request_service('org.gnome.SessionManager')
    power_inhibit = @bus.request_service('org.freedesktop.PowerManagement.Inhibit')
    screensaver = @bus.request_service('org.freedesktop.ScreenSaver')
    shell = @bus.request_service('org.gnome.Shell')
  end
end

if __FILE__ == $0
  begin
    if script_name = ARGV.first
      command = CustomScreenshotCommand.new(script_name)
      GnomeDBusEmulation.new.run!(screenshot_command: command)
    else
      GnomeDBusEmulation.new.run!
    end
  rescue DBus::Connection::NameRequestError
    puts 'Service already running'
  end
end
