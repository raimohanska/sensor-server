R = require "ramda"
log = require "./log"
B=require "baconjs"
moment=require "moment"
config = (require "./config")
now = -> moment()
oneSecond = 1000
oneHour = 3600 * oneSecond
oneMinute = 60 * oneSecond
eachSecondE = B.interval(1000).map(now)
eachMinuteE = eachSecondE.filter((time) -> time.seconds() == 0)
eachHourE = eachMinuteE.filter((time) -> time.minutes() == 0)
midnightE = eachHourE.filter((time) -> time.hours() == 0)
hourOfDayP = eachHourE.toProperty(0).map(now).map(".hours").toProperty().skipDuplicates()

formatDuration = (millis) -> moment.duration(millis, 'milliseconds').humanize()

module.exports = {
  eachSecondE, eachMinuteE, eachHourE, midnightE,
  hourOfDayP,
  oneHour, oneMinute, oneSecond,
  formatDuration }
