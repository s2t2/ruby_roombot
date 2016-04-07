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
      @drive_action_in_progress = false
    end

    def heartbeat
      if @drive_action_in_progress == true
        info("SUPPRESSING HEARTBEAT")
        return true
      end
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
        @drive_action_in_progress = false
      elsif decoded["event"] == "sensor_update"
        bumpers = {
          left: decoded["payload"]["bumper_left"],
          right: decoded["payload"]["bumper_right"]
        }

        if bumpers[:left] || bumpers[:right]
          info("ABOUT TO BUMP INTO SOMETHING !!! #{bumpers[:left]} | #{bumpers[:right]}")

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

          info("BUMP DIRECTION -- #{bump_direction} -- #{lights[:left].values} | #{lights[:right].values}")

          back_up
          sleep 2.0
          @drive_action_in_progress = false

          case bump_direction
          when "center","center_left"
            turn_slight_right
          when "left"
            turn_hard_right
          when "center_right"
            turn_slight_left
          when "right"
            turn_hard_left
          #else
            #drive_forward
          end

          sleep 2.0
          @drive_action_in_progress = false
          drive_forward
        end
      end
    end

    def drive_forward
      info("DRIVING FORWARD")
      @drive_action_in_progress = true
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: 500, radius: 0})
    end

    def back_up
      info("BACKING UP")
      @drive_action_in_progress = true
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: -200, radius: 0})
    end

    def turn_hard_right
      info("TURNING HARD RIGHT")
      @drive_action_in_progress = true
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: 10, radius: -25})
    end

    def turn_slight_right
      info("TURNING SLIGHT RIGHT")
      @drive_action_in_progress = true
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: 10, radius: -50})
    end

    def turn_hard_left
      info("TURNING HARD LEFT")
      @drive_action_in_progress = true
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: 10, radius: 25})
    end

    def turn_slight_left
      info("TURNING SLIGHT LEFT")
      @drive_action_in_progress = true
      send(topic: channel, event: "drive", ref: 15, payload: {velocity: 10, radius: 50})
    end






















    def on_close(code, reason)
      debug("websocket connection closed: #{code.inspect}, #{reason.inspect}")
    end
  end
end
