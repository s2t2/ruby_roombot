require 'json'
require 'celluloid/websocket/client'
require 'pry'

module RubyRoombot
  class Client
    include Celluloid
    include Celluloid::Logger

    attr_reader :connection, :channel

    def initialize(url, channel)
      @connection = Celluloid::WebSocket::Client.new(url, current_actor)
      @channel = channel
    end

    def heartbeat
      send(topic: "phoenix", event: "heartbeat", payload: {}, ref: 10)
    end

    def join
      send({
        topic: channel,
        event: "phx_join",
        payload: {},
        ref: 1,
      })
    end

    def send(message)
      encoded = ::JSON.generate(message)
      if connection.text encoded
        #info("SENT DATA -- #{encoded}")
      else
        error("FAILD TO SEND DATA -- #{encoded}")
      end
    end

    def on_open
      debug("websocket connection opened")
      join
    end




















    def on_message(data)
      decoded = ::JSON.parse(data)
      info("RECEIVED DATA (#{decoded["event"]}) -- #{decoded}")

      if decoded["event"] == "phx_reply" && decoded["ref"] == 1 #joined the topic
        info("JOINED THE TOPIC")
        drive_forward
      elsif decoded["event"] == "sensor_update"
        br = decoded["payload"]["bumper_right"]
        bl = decoded["payload"]["bumper_left"]
        if bl || br
          info("ABOUT TO BUMP INTO SOMETHING !!! R: #{br} -- L: #{bl}")
          drive_in_circles
        end
      end
    end

    def drive_in_circles
      info("DRIVING IN CIRCLES")
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: 100, radius: 50})
    end

    def drive_forward
      info("DRIVING FORWARD")
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: 500, radius: 0})
    end




















    def on_close(code, reason)
      debug("websocket connection closed: #{code.inspect}, #{reason.inspect}")
    end
  end
end
