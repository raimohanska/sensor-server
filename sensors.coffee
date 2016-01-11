R = require "ramda"
log = require "./log"
B=require "baconjs"
HttpServer = require "./http-server"
validate = require "./validate"
mapProperties = require "./property-mapping"
config = require "./config"

sensorE = HttpServer.sensorE
  .flatMap(validate)
  .map(mapProperties)

sensorP = (props) -> sensorE.filter(R.whereEq props).map(".value").toProperty()

B.Observable :: isBelowWithHysteresis = (lowLimit, highLimit) ->
  this
    .scan false, (prev, val) ->
      if prev
        val < highLimit
      else
        val < lowLimit
    .skipDuplicates()

module.exports = { sensorE, sensorP }
