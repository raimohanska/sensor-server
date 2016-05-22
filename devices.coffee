B = require 'baconjs'
require './bacon-extensions'
R = require 'ramda'
L = require 'partial.lenses'
time = require './time'

log = require "./log"
carrier = require "carrier"
devices = (require "./config").devices || {}
store = require("./store")("latest-values")

deviceSeenE = B.Bus()

updateDeviceSeen = (deviceStatii, key) ->
  L.set(L.compose(key, "lastSeen"), time.now().toString(), deviceStatii)

devicesStatusP = B.update(
  R.fromPairs(R.keys(devices).map((key) -> [key, {}])),
  [deviceSeenE], updateDeviceSeen
  [store.read().toEventStream()], (_, storedState) -> storedState
).persist("deviceStatus")

reportDeviceSeen = (key) -> if key?
  deviceSeenE.push(key)

module.exports = { reportDeviceSeen }
