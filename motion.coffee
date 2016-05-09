time = require "./time"
B = require "baconjs"
sensors = require "./sensors"

occupiedP = (location, throttle = time.oneMinute * 30) ->
    motionP = sensors.sensorP({type: "motion", location}).map((x) -> x > 0)
    motionOn = motionP.changes().filter((x) -> x)
    motionOff = motionP.changes().filter((x) -> !x)
    motionOn
      .flatMapLatest (x) -> B.once(x).concat(motionOff.delay(throttle).map(false))
      .toProperty(0).skipDuplicates()

inactiveE = (location, throttle = time.oneHour) ->
  occupiedP(location, throttle)
    .changes()
    .filter((x) -> !x)
    .map(location + " unoccupied for " + time.formatDuration(throttle))

module.exports = {occupiedP, inactiveE}
