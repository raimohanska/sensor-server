R = require "ramda"
log = require "./log"
B=require "baconjs"
validate = require "./validate"

initSite = (site) ->
  devices = site.config.devices || {}

  mapProperties = (event) ->
    device = devices[event.device]
    if device?
      properties = device.properties || {}
      sensorProperties = device.sensors?[event.sensor] || {}
      R.mergeAll([event, properties, sensorProperties])
    else
      event

  eventBus = B.Bus()

  sensorE = eventBus
    .flatMap(validate)
    .map(mapProperties)

  pushEvent = eventBus.push.bind(eventBus)

  sensorP = (props) -> sensorE.filter(R.whereEq props).map(".value").toProperty()

  sourceHash = (event) -> R.join('')(R.chain(
    (([k,v]) ->
      if k == "value" || typeof v == "object" then [] else [k+v]
    ),
    R.toPairs(event)))

  { sensorE, sensorP, pushEvent, sourceHash }

module.exports = { initSite }
