R = require "ramda"
log = require "./log"
B=require "baconjs"
moment=require "moment"
now = -> moment()
oneSecond = 1000
oneMinute = 60 * oneSecond
oneHour = 3600 * oneSecond
oneDay = 24 * oneHour
seconds = (x) -> x * oneSecond
minutes = (x) -> x * oneMinute
hours = (x) -> x * oneHour
days = (x) -> x * oneDay
eachSecondE = B.interval(1000).map(now)
eachMinuteE = eachSecondE.filter((t) -> t.seconds() == 0)
eachHourE = eachMinuteE.filter((t) -> t.minutes() == 0)
midnightE = eachHourE.filter((t) -> t.hours() == 0)
hourOfDayP = eachHourE.toProperty(0).map(now).map(".hours").toProperty().skipDuplicates()

formatDuration = (millis) -> moment.duration(millis, 'milliseconds').humanize()

module.exports = {
  now,
  eachSecondE, eachMinuteE, eachHourE, midnightE,
  hourOfDayP,
  oneDay, oneHour, oneMinute, oneSecond,
  days, hours, minutes, seconds,
  formatDuration }
