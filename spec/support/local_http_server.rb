# frozen_string_literal: true

require 'socket'

class LocalHttpServer
  attr_reader :accepts

  def initialize(body: 'ok', drop_after_response: false)
    @body = body
    @drop_after_response = drop_after_response
    @server = TCPServer.new('127.0.0.1', 0)
    @accepts = 0
    @thread = Thread.new { loop { serve_async(@server.accept) } }
  end

  def url(path = '/')
    "http://127.0.0.1:#{@server.addr[1]}#{path}"
  end

  def stop
    @thread.kill
    @server.close
  end

  private

  def serve_async(socket)
    @accepts += 1
    Thread.new { serve(socket) }
  end

  def serve(socket)
    while (line = socket.gets)
      next unless line == "\r\n"

      socket.write("HTTP/1.1 200 OK\r\nContent-Length: #{@body.bytesize}\r\n\r\n#{@body}")
      break if @drop_after_response
    end
  ensure
    socket.close
  end
end
