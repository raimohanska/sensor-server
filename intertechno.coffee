R = require "ramda"
log = require "./log"

initSite = (site) ->
  itConfig = site.config.intertechno
  if not itConfig
    return null
  pin = itConfig.transmitPin
  log "init intertechno for pin " + pin
  sender =  try
    require('node-intertechno-sender') # May throw an error if /dev/gpiomem is not accessible
  catch e
    log "Module node-intertechno-sender not installed, using mock Intertechno interface"
    {
      enableTransmit: (pin) ->
      setRepeatTransmit: (count) ->
      setState: (id, state) -> log "Pretending to send " + id + "=" + state + " on pin " + pin
    }
  sender.enableTransmit(pin)
  sender.setRepeatTransmit(5)
  if site.houm
    R.values(site.config.devices)
      .filter (d) -> d.properties?.intertechnoId && d.properties.lightId
      .forEach (d) ->
        brightnessP = site.houm.lightStateP(d.properties.lightId).map('.value')
        brightnessP.forEach (bri) ->
          state = bri > 0
          log "Intertechno " + d.properties.intertechnoId + " state=" + state
          sender.setState d.properties.intertechnoId, state

module.exports = { initSite }