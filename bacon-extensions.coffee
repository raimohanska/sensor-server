B = require "baconjs"
time = require "./time"
scale = require "./scale"
log = require "./log"

B.range = (start, end, interval) ->
  B.repeat (i) ->
    next = i + start
    if next < end
      B.later(interval, next)
    else
      false

B.Observable :: repeatBy = (keyF, interval) ->
  src = this
  src.flatMap (event) ->
    key = keyF(event)
    B.once(event).concat(B.interval(interval, event).takeUntil(src.filter((e) -> keyF(e) == key)))

B.Observable :: isBelowWithHysteresis = (lowLimit, highLimit) ->
  this
    .scan false, (prev, val) ->
      if prev
        val < highLimit
      else
        val < lowLimit
    .skipDuplicates()

B.Observable :: smooth = (fadeStepTime = time.oneSecond, fadeStep = 0.1) ->
  src = this
  value = undefined
  src.flatMapLatest (newValue) ->
    startValue = value
    diff = (newValue - startValue) / fadeStep
    steps = Math.floor(Math.abs(diff))
    if value == undefined or steps == 0
      value = newValue
      B.once(value)
    else
      #log "smoothing", value, newValue, "in", steps
      B.range(0, steps, fadeStepTime)
        .map (step) ->
          value = scale(step + 1, 0, steps, startValue, newValue)
          value
        .concat(B.once(newValue))
        .skipDuplicates()
