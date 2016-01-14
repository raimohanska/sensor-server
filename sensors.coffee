R = require "ramda"
log = require "./log"
B=require "baconjs"
HttpServer = require "./http-server"
validate = require "./validate"
mapProperties = require "./property-mapping"
config = require "./config"

eventBus = B.Bus()

sensorE = eventBus.merge(HttpServer.sensorE)
  .flatMap(validate)
  .map(mapProperties)

pushEvent = eventBus.push.bind(eventBus)

sensorE.log("storing")

sensorP = (props) -> sensorE.filter(R.whereEq props).map(".value").toProperty()

module.exports = { sensorE, sensorP, pushEvent }
