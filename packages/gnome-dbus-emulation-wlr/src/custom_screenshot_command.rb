require 'open3'

class CustomScreenshotCommand
  def initialize(script)
    @script = script
  end

  def call(filename, cursor:, flash:)
    show_cursor = cursor ? 'showcursor' : 'nocursor'
    show_flash = flash ? 'showflash' : 'noflash'

    stdout, stderr, status = Open3.capture3(@script, filename, show_cursor, show_flash)
    puts stderr unless stderr.empty?

    status == 0
  end
end

