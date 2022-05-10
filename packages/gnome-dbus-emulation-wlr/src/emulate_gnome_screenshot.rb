require 'dbus'
require_relative './portal_screenshot'
require_relative './portal_screenshot_command'

class EmulateGnomeScreenshot
  SERVICE_NAME = 'org.gnome.Shell.Screenshot'
  OBJECT_NAME = '/org/gnome/Shell/Screenshot'

  def initialize(bus: DBus.session_bus, command: nil, log: true)
    @bus = bus
    @log = log
    @command = command || PortalScreenshotCommand.new
  end

  def request_service
    @bus.request_service(SERVICE_NAME)
  end

  def register_screenshot_interface(service)
    service.export(screenshot_interface)
  end

  def run!
    service = request_service
    register_screenshot_interface(service)

    main = DBus::Main.new
    main << @bus
    main.run
    main
  end

  private

  def screenshot_interface
    ScreenshotInterface.new(path: OBJECT_NAME, log: @log, command: @command)
  end

  class ScreenshotInterface < DBus::Object
    def initialize(command:, path:, log: true)
      @command = command
      raise 'Invalid Screenshot Command' unless @command
      @log = log

      super(path)
    end

    def log?
      @log
    end

    dbus_interface(SERVICE_NAME) do
      dbus_method :Screenshot, "in include_cursor:b, in flash:b, in filename:s, out success:b, out filename_used:s" do |include_cursor, flash, filename|
        puts "emulating Gnome Screenshot(include_cursor: #{include_cursor}, flash: #{flash}, filename: #{filename})" if log?

        success = @command.call(filename, cursor: include_cursor, flash: flash)

        [success, filename]
      end
    end
  end
end
