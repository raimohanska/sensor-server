B = require 'baconjs'
require './bacon-extensions'
R = require 'ramda'
L = require 'partial.lenses'
time = require './time'
mail = require './mail'
log = require "./log"
carrier = require "carrier"
devices = (require "./config").devices || {}
initialDevicesStatii = R.fromPairs(R.keys(devices).map((key) -> [key, {}]))
sensors = require "./sensors"

missingDeviceThreshold = time.oneHour * 6
started = time.now()

deviceSeenE = B.Bus()

updateDeviceSeen = (deviceStatii, key) ->
  L.set(L.compose(key, "lastSeen"), time.now().toString(), deviceStatii)

devicesStatusP = B.update(
  initialDevicesStatii,
  [deviceSeenE], updateDeviceSeen
)

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
    ages = mapValues((age) ->
      age > missingDeviceThreshold
    )(statii)
    filtered=filterValues(R.identity)(ages)
    R.keys(filtered))
  .skipDuplicates(R.equals)

missingDevicesP.filter(".length").forEach (missing) ->
  names = missing.map((d) -> devices[d]?.name || d)
  text = "Following devices seem to have gone offline: " + names.join(",")
  mail.send(missing.length + " devices offline", text)

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
