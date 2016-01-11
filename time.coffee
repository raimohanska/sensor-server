R = require "ramda"
log = require "./log"
B=require "baconjs"
moment=require "moment"
config = (require "./config")

oneHour = 3600 * 1000
oneMinute = 60 * 1000
eachSecondE = B.interval(1000).map(-> moment())
eachMinuteE = eachSecondE.filter((time) -> time.seconds() == 0)

module.exports = { eachSecondE, eachMinuteE }
