log = require "./log"
devices = (require "./config").devices || {}
R = require "ramda"

mapProperties = (event) ->
  device = devices[event.device]
  if device?
    properties = device.properties || {}
    sensorProperties = device.sensors?[event.sensor] || {}
    R.mergeAll([event, properties, sensorProperties])
  else
    event

module.exports = mapProperties
