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

B.Observable :: repeatBy = (keyF, interval, throttle = time.oneSecond) ->
  src = this
  src.flatMap (event) ->
    key = keyF(event)
    B.once(event)
      .concat(B.interval(interval, event)
      .takeUntil(src.filter((e) -> keyF(e) == key)))
      .throttle(throttle)

B.Observable :: isBelowWithHysteresis = (lowLimit, highLimit) ->
  this
    .scan false, (prev, val) ->
      if prev
        val < highLimit
      else
        val < lowLimit
    .skipDuplicates()

B.fade = (from, to, fadeStepTime = 100, fadeStep = 0.1) ->
  diff = (to - from) / fadeStep
  steps = Math.floor(Math.abs(diff))
  if from == undefined or steps == 0
    log "set to", to
    B.once(to)
  else
    log "fade from", from, "to", to, "in", steps, " steps"
    B.range(0, steps, fadeStepTime)
      .map (step) ->
        scale(step + 1, 0, steps, from, to)
      .concat(B.once(to))

B.Property :: smooth = (fadeStepTime = 100, fadeStep = 0.1) ->
  src = this
  value = undefined
  src
    .flatMapLatest (newValue) ->
      B.fade(value, newValue, fadeStepTime, fadeStep)
        .map (newValue) ->
          value = newValue
          value
    .toProperty()
    .skipDuplicates()

B.Property :: combineWithHistory = (delay, combinator) ->
  this
    .delay(delay)
    .combine this, combinator
    .skipDuplicates()

B.Property :: hasMaintainedValueForPeriod = (value, period) ->
  this
    .skipDuplicates()
    .flatMapLatest (x) ->
      if x == value
        B.once(false).concat(B.later(period, true))
      else
        false
    .toProperty(false)
    .skipDuplicates()
