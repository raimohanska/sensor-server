R = require "ramda"
log = require "./log"
B=require "baconjs"
moment=require "moment"
config = (require "./config")
now = -> moment()
oneSecond = 1000
oneMinute = 60 * oneSecond
oneHour = 3600 * oneSecond
oneDay = 24 * oneHour
eachSecondE = B.interval(1000).map(now)
eachMinuteE = eachSecondE.filter((time) -> time.seconds() == 0)
eachHourE = eachMinuteE.filter((time) -> time.minutes() == 0)
midnightE = eachHourE.filter((time) -> time.hours() == 0)
hourOfDayP = eachHourE.toProperty(0).map(now).map(".hours").toProperty().skipDuplicates()

formatDuration = (millis) -> moment.duration(millis, 'milliseconds').humanize()

module.exports = {
  now,
  eachSecondE, eachMinuteE, eachHourE, midnightE,
  hourOfDayP,
  oneDay, oneHour, oneMinute, oneSecond,
  formatDuration }
