net = require 'net'
B = require 'baconjs'
R = require 'ramda'
log = require "./log"

client = new net.Socket()
client.connect 8001, "localhost", ->
  console.log "connected"
  carrier = (require "carrier").carry client
  client.write(JSON.stringify({ device: "testdevice" }) + "\n")
  carrier.on "line", (line) ->
    log line
