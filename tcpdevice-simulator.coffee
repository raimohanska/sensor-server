net = require 'net'
B = require 'baconjs'
R = require 'ramda'
log = require "./log"

args = process.argv.slice(2)
host = args[0] || "localhost"
port = args[1] || 8001

client = new net.Socket()
client.connect port, host, ->
  console.log "connected"
  carrier = (require "carrier").carry client
  client.write(JSON.stringify({ device: "testdevice" }) + "\n")
  carrier.on "line", (line) ->
    log line
