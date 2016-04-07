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

      if decoded["event"] == "phx_reply" && decoded["ref"] == 1 # joined the topic
        info("JOINED THE TOPIC")
        drive_forward
      elsif decoded["event"] == "sensor_update"
        bumpers = {
          left: decoded["payload"]["bumper_left"],
          right: decoded["payload"]["bumper_right"]
        }

        if bumpers[:left] || bumpers[:right]
          lights = {
            left:{
              extreme: decoded["payload"]["light_bumper_left"],
              middle: decoded["payload"]["light_bumper_left_front"],
              center: decoded["payload"]["light_bumper_left_center"]
            },
            right:{
              center: decoded["payload"]["light_bumper_right_center"],
              middle: decoded["payload"]["light_bumper_right_front"],
              extreme: decoded["payload"]["light_bumper_right"]
            }
          }

          bump_direction = if lights[:left][:center] == 1 && lights[:right][:center] == 1
            "center"
          elsif lights[:left][:center] == 1 && lights[:right][:center] == 0
            "center_left"
          elsif lights[:left][:center] == 0 && lights[:right][:center] == 1
            "center_right"
          elsif lights[:left][:middle] == 1 || lights[:left][:extreme] == 1
            "left"
          elsif lights[:right][:middle] == 1 || lights[:right][:extreme] == 1
            "right"
          else
            "OOPS"
          end

          info("ABOUT TO BUMP INTO SOMETHING !!! #{bumpers} -- #{lights} -- #{bump_direction}")

          back_up
          sleep 2.0

          case bump_direction
          when "center","center_left","left"
            circle_right
          when "center_right","right"
            circle_left
          #else
            #drive_forward
          end

          sleep 2.0
          drive_forward
        end
      end
    end

    def drive_forward
      info("DRIVING FORWARD")
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: 500, radius: 0})
    end

    def back_up
      info("BACKING UP")
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: -200, radius: 0})
    end

    def circle_right
      info("TURNING RIGHT")
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: 10, radius: -25})
    end

    def circle_left
      info("TURNING LEFT")
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: 10, radius: 25})
    end






















    def on_close(code, reason)
      debug("websocket connection closed: #{code.inspect}, #{reason.inspect}")
    end
  end
end
