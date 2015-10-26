require('es6-promise').polyfill()
R = require "ramda"
TcpSimple = require "./tcp-simple-protocol"
log = require "./log"
B=require "baconjs"
KeenSender = require "./keen-sender"
HttpServer = require "./http-server"
Influx = require "./influx-store"
validate = require "./validate"
mapProperties = require "./property-mapping"

sensorEvents = TcpSimple.sensorEvents.merge(HttpServer.sensorEvents)
  .flatMap(validate)
  .map(mapProperties)

sensorEvents
  .onValue(KeenSender.send)

sensorEvents
  .onValue(Influx.store)

sensorEvents
  .onError (error) -> log("ERROR: " + error)
