time = require "./time"
B = require "baconjs"
sensors = require "./sensors"

motionP = (location) ->
    sensors.sensorP({type: "motion", location}).map((x) -> x > 0)

motionStartE = (location) -> motionP(location).changes().filter((x) -> x)
motionEndE = (location) -> motionP(location).changes().filter((x) -> !x)

occupiedP = (location, throttle = time.oneMinute * 30) ->
    motionStartE(location)
      .flatMapLatest (x) -> B.once(x).concat(motionEndE(location).delay(throttle).map(false))
      .toProperty(0).skipDuplicates()

inactiveE = (location, throttle = time.oneHour) ->
  occupiedP(location, throttle)
    .changes()
    .filter((x) -> !x)
    .map(location + " unoccupied for " + time.formatDuration(throttle))

module.exports = {occupiedP, motionStartE, motionEndE, motionP, inactiveE}
