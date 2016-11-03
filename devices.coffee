B = require 'baconjs'
require './bacon-extensions'
R = require 'ramda'
L = require 'partial.lenses'
time = require './time'
mail = require './mail'
log = require "./log"
carrier = require "carrier"
devices = (require "./config").devices || {}
store = require("./store")("latest-values")
sensors = require "./sensors"

missingDeviceThreshold = time.hours * 6
started = time.now()

deviceSeenE = B.Bus()

updateDeviceSeen = (deviceStatii, key) ->
  L.set(L.compose(key, "lastSeen"), time.now().toString(), deviceStatii)

devicesStatusP = B.update(
  R.fromPairs(R.keys(devices).map((key) -> [key, {}])),
  [deviceSeenE], updateDeviceSeen
  [store.read().toEventStream()], (_, storedState) -> storedState
).persist("deviceStatus", false)

timeSinceSeenDevicesP = devicesStatusP.sampledBy(time.eachSecondE)
  .toProperty()
  .map (statii) -> mapValues((value) -> age(value.lastSeen))(statii)

timeSinceSeenDevicesP
  .sample(time.oneHour)
  .flatMap((statii) ->
    events = R.toPairs(statii).map(([device, value]) -> { type: "delay", device, value })
    B.fromArray(events))
  .filter(".value")
  .forEach(sensors.pushEvent)

missingDevicesP = timeSinceSeenDevicesP
  .map((statii) ->
    ages = mapValues((age) -> age > missingDeviceThreshold)(statii)
    filtered=filterValues(R.identity)(ages)
    R.keys(filtered))
  .skipDuplicates(R.equals)
  .log "missing devices"

missingDevicesP.filter(".length").forEach (missing) ->
  text = "Sensor devices missing: " + missing.join(",")
  mail.send text, text

mapValues = (f) -> (obj) ->
  R.fromPairs(R.toPairs(obj).map(([key, value]) -> [key, f(value)]))

filterValues = (f) -> (obj) ->
  R.fromPairs(R.toPairs(obj).filter(([key, value]) -> f(value)))

age = (t) ->
  time.now().diff(t || started)

devicesStatusP.throttle(time.oneMinute * 10).log("deviceStatus")

reportDeviceSeen = (key) -> if key?
  deviceSeenE.push(key)

module.exports = { reportDeviceSeen }
