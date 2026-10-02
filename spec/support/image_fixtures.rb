# frozen_string_literal: true

require 'zlib'

# Smallest valid headers FastImage can identify, so probes run without real images.
module ImageFixtures
  module_function

  def png(width, height)
    ihdr = ['IHDR', [width, height].pack('NN'), "\x08\x06\x00\x00\x00".b].join
    "\x89PNG\r\n\x1a\n".b + [13].pack('N') + ihdr + [Zlib.crc32(ihdr)].pack('N')
  end

  def ico(width, height)
    [0, 1, 1].pack('v3') + [width % 256, height % 256, 0, 0, 1, 32, 0, 22].pack('C4v2V2')
  end

  def svg(width = nil, height = nil)
    size = width && height ? %( width="#{width}" height="#{height}") : ''
    %(<svg xmlns="http://www.w3.org/2000/svg"#{size} viewBox="0 0 10 10"></svg>)
  end
end
