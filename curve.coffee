B = require "baconjs"
time = require "./time"

parseTime = (str) ->
  parse = (s) -> (parseInt(s) || 0)
  [h, m, s] = str.split(":")
  {
    h: parse(h)
    m: parse(m)
    s: parse(s)
    today: -> time.todayAt(this.h, this.m, this.s)
    tomorrow: -> this.today().add(1, "day")
    yesterday: -> this.today().add(-1, "day")
    isAfter: (t) -> this.today().isAfter(t)
  }

div = (x,y) -> (if x < 0 then x + y else x) % y

Array::indexWhere = (f) ->
  for v, i in this
    if f(v) then return i
  -1

Curve = (points) ->
  points = points.map ({time, value}) -> { time: parseTime(time), value }
  (t) ->
    nextPointIndex = points.indexWhere (p) -> p.time.isAfter(t)
    if nextPointIndex < 0
      prevPoint = points[points.length - 1]
      prevPoint = { time: prevPoint.time.today(), value: prevPoint.value }
      nextPoint = points[0]
      nextPoint = { time: nextPoint.time.tomorrow(), value: nextPoint.value }
    else if nextPointIndex == 0
      prevPoint = points[points.length - 1]
      prevPoint = { time: prevPoint.time.yesterday(), value: prevPoint.value }
      nextPoint = points[0]
      nextPoint = { time: nextPoint.time.today(), value: nextPoint.value }
    else
      prevPoint = points[nextPointIndex - 1]
      prevPoint = { time: prevPoint.time.today(), value: prevPoint.value }
      nextPoint = points[nextPointIndex]
      nextPoint = { time: nextPoint.time.today(), value: nextPoint.value }

    periodStart = prevPoint.time.toDate().getTime()
    periodLength = nextPoint.time.toDate().getTime() - periodStart
    periodOffset = t.toDate().getTime() - periodStart
    prevPoint.value + (nextPoint.value - prevPoint.value) * periodOffset / periodLength

Curve.curveProperty = (p) ->
  B.combineTemplate({
    curve: p
    time: time.eachSecondE
  }).map(({curve, time}) -> Math.round(Curve(curve)(time)))
    .skipDuplicates()

exampleCurve = Curve([
  { time: "8:00", value: 0 }
  { time: "8:30", value: 50 }
  { time: "20:00", value: 50 }
  { time: "21:00", value: 0 }
])

#console.log exampleCurve(time.todayAt("20:30"))

module.exports = Curve
