time = require "./time"
B = require "baconjs"
sensors = require "./sensors"

occupiedP = (location, throttle = time.oneMinute * 30) ->
    motionP = sensors.sensorP({type: "motion", location})
    motionOn = motionP.changes().filter((x) -> x > 0)
    motionOff = motionP.changes().filter((x) -> x == 0)
    motionOn
      .flatMapLatest (x) -> B.once(x).concat(motionOff.delay(throttle).map(0))
      .toProperty(0).skipDuplicates()

module.exports = {occupiedP}
