Bacon = require "baconjs"
show = JSON.stringify
R = require "ramda"

validate = (sensorEvent) ->
  if !sensorEvent.value?
    new Bacon.Error("value attribute missing from " + show(sensorEvent))
  else if R.keys(sensorEvent).length < 2
    new Bacon.Error("at least 2 attributes required in " + show(sensorEvent))
  else
    sensorEvent

module.exports = validate
