#!/usr/bin/env ruby

require 'dbus'
require 'timeout'
require 'securerandom'

class PortalScreenshot
  PORTAL_PREFIX = 'org.freedesktop.portal.'
  OBJECT_PATH = '/org/freedesktop/portal/desktop'

  def initialize(bus: DBus.session_bus)
    @bus = bus
  end

  def screenshot(parent_window: '')
    main = DBus::Main.new
    main << @bus

    request = Request.new(@bus)
    screenshot_interface.Screenshot(parent_window, request.options)
    request.interface.on_signal('Response') do |*args|
      response = Response.new(*args)
      if response.success?
        if block_given?
          yield(response)
        else
          puts response.uri
        end
      else
        raise "Screenshot failed: #{response.result.inspect}"
      end
    ensure
      main.quit
    end

    begin
    Timeout::timeout(10) do
      main.run
    end
    rescue Timeout::Error
      $stderr.puts 'Timeout on portal dbus, check it is running'
    end
  end

  private

  def screenshot_interface
    service = @bus.service(PORTAL_PREFIX + 'Desktop')
    service.object(OBJECT_PATH)[PORTAL_PREFIX + 'Screenshot']
  end

  class Response
    attr_reader :result

    def initialize(response, result)
      @response = response
      @result = result
    end

    def success?
      @response == 0
    end

    def uri
      result['uri']
    end
  end

  class Request
    def initialize(bus)
      @bus = bus
      @id = SecureRandom.hex(16)
    end

    def options
      { 'handle_token' => token }
    end

    def interface
      service = @bus.service(PORTAL_PREFIX + 'Desktop')

      # Create ProxyObjectInterface directly to bypass introspection,
      # since the interface may not have been created yet
      DBus::ProxyObjectInterface.new(service.object(handle), PORTAL_PREFIX + 'Request')
    end

    private

    def handle
      "/org/freedesktop/portal/desktop/request/#{sender_name}/#{token}"
    end

    def token
      "dbus_portal_screenshot_rb_#{@id}"
    end

    def sender_name
      @bus.unique_name.sub('.', '_').delete_prefix(':')
    end
  end
end

# Usage: `ruby portal_screenshot.rb` to open with default viewer
# Usage: `ruby portal_screenshot.rb screenshot-destination.png`
if __FILE__ == $0
  begin
    filename = ARGV.first
    PortalScreenshot.new.screenshot do |response|
      if filename
        require 'fileutils'
        path = URI.parse(response.uri).path
        FileUtils.mv(path, filename)
      else
        system('xdg-open', response.uri)
      end
    rescue DBus::Error
      puts 'Portal not running'
    end
  end
end
