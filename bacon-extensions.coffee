B = require "baconjs"
time = require "./time"
scale = require "./scale"
log = require "./log"
store = require("./store")("latest-values")

B.range = (start, end, interval) ->
  B.repeat (i) ->
    next = i + start
    if next < end
      B.later(interval, next)
    else
      false

B.Observable :: withLatestFrom = (other, f) ->
  other.sampledBy this, (v2, v1) -> f(v1, v2)

B.Observable :: repeatBy = (keyF, interval, {throttle, maxRepeat}) ->
  src = this
  src
    .flatMap (event) ->
      key = keyF(event)
      keyEvents = B.once(event)
        .concat(B.interval(interval, event)
          .takeUntil(src.filter((e) -> keyF(e) == key)))
      if throttle?
        keyEvents = keyEvents.throttle(throttle)
      if maxRepeat?
        keyEvents = keyEvents.takeUntil(B.later(maxRepeat))
      keyEvents

B.Observable :: repeatLatest = (interval) ->
  this.flatMapLatest (value) ->
    B.once(value).concat(B.interval(interval, value))

B.Property :: isBelowWithHysteresis = (lowLimit, highLimit) ->
  state = B.combineTemplate { lowLimit, highLimit, value: this }
  state
    .scan false, (prev, {lowLimit, highLimit, value}) ->
      if prev
        value < highLimit
      else
        value < lowLimit
    .skipDuplicates()

B.fade = (from, to, fadeStepTime = 100, fadeStep = 0.1) ->
  diff = (to - from) / fadeStep
  steps = Math.floor(Math.abs(diff))
  if from == undefined or steps == 0
    #log "set to", to
    B.once(to)
  else
    #log "fade from", from, "to", to, "in", steps, " steps"
    B.range(0, steps, fadeStepTime)
      .map (step) ->
        scale(0, steps, from, to)(step + 1)
      .concat(B.once(to))

B.Property :: persist = (key, shouldLog = true) ->
  startValueP = store.read(key)
  this.changes().forEach (value) -> store.write(key, value)
  data = startValueP.toEventStream().concat(this).toProperty().skipDuplicates()
  if shouldLog then data.log(key) else data

B.Property :: smooth = ({stepTime, step} = {stepTime: 100, step: 0.1}) ->
  src = this
  value = undefined
  src
    .flatMapLatest (newValue) ->
      B.fade(value, newValue, stepTime, step)
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
