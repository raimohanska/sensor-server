R = require "ramda"
log = require "./log"
B=require "baconjs"
validate = require "./validate"
mapProperties = require "./property-mapping"
config = require "./config"

eventBus = B.Bus()

sensorE = eventBus
  .flatMap(validate)
  .map(mapProperties)

pushEvent = eventBus.push.bind(eventBus)

sensorP = (props) -> sensorE.filter(R.whereEq props).map(".value").toProperty()

module.exports = { sensorE, sensorP, pushEvent }
