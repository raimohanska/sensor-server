time = require "./time"
B = require "baconjs"
sensors = require "./sensors"

motionP = (location) ->
    sensors.sensorP({type: "motion", location}).map((x) -> x > 0)

motionStartE = (location) -> motionP(location).changes().filter((x) -> x)
motionEndE = (location) -> motionP(location).changes().filter((x) -> !x)

occupiedP = (location, throttle = time.minutes(30)) ->
    motionStartE(location)
      .flatMapLatest (x) -> B.once(x).concat(motionEndE(location).delay(throttle).map(false))
      .toProperty(0).skipDuplicates()

inactiveE = (location, throttle = time.oneHour) ->
  occupiedP(location, throttle)
    .changes()
    .filter((x) -> !x)
    .map(location + " unoccupied for " + time.formatDuration(throttle))

motionStartingInDarkP = (location, darkP) ->
  motionStartE(location).filter(darkP) # liike alkaa hämärässä
    .flatMapLatest(-> B.once(true).concat(motionEndE(location).map(false)))
    .toProperty(false)

module.exports = {occupiedP, motionStartE, motionEndE, motionP, inactiveE, motionStartingInDarkP}
