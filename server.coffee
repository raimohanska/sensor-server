R = require "ramda"
TcpSimple = require "./tcp-simple-protocol"
log = require "./log"
B=require "baconjs"
KeenSender = require "./keen-sender"
HttpServer = require "./http-server"
validate = require "./validate"

sensorEvents = TcpSimple.sensorEvents.merge(HttpServer.sensorEvents)
  .flatMap(validate)

sensorEvents
  .onValue(KeenSender.send)

sensorEvents
  .onError (error) -> log("ERROR: " + error)
