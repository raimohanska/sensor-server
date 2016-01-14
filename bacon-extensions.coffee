B = require "baconjs"

B.Observable :: repeatBy = (keyF, interval) ->
  src = this
  src.flatMap (event) ->
    key = keyF(event)
    console.log("new key", key)
    B.interval(interval, event).takeUntil(src.filter((e) -> keyF(e) == key))

B.Observable :: isBelowWithHysteresis = (lowLimit, highLimit) ->
  this
    .scan false, (prev, val) ->
      if prev
        val < highLimit
      else
        val < lowLimit
    .skipDuplicates()
