R = require "ramda"
log = require "./log"
B=require "baconjs"
moment=require "moment"
rp = require 'request-promise'
config =  require "./config"
time = require "./time"
scale = require "./scale"

parseTime = (str) -> 
  moment(str + " +0000", "h:mm:ss A Z")

ONE_HOUR = 3600 * 1000
LIGHT = 255
DARK = 0

sunLightInfoP = B.once().concat(B.interval(ONE_HOUR))
  .flatMap -> B.fromPromise(rp("http://api.sunrise-sunset.org/json?lat="+config.latitude+"&lng="+config.longitude+"&date=today"))
  .map(JSON.parse)
  .map(".results")
  .toProperty()
  .skipDuplicates(R.equals)
  .map (sunInfo) ->
    {
      twilightBegin: parseTime(sunInfo.civil_twilight_begin)
      sunrise: parseTime(sunInfo.sunrise)
      sunset: parseTime(sunInfo.sunset)
      twilightEnd: parseTime(sunInfo.civil_twilight_end)
    }

sunBrightnessP = B.combineAsArray(sunLightInfoP, time.eachSecondE)
  .map ([sunInfo, currentTime]) ->
    #currentTime = currentTime.subtract(11, 'h')
    if currentTime.isBefore(sunInfo.twilightBegin) || currentTime.isAfter(sunInfo.twilightEnd)
      DARK
    else if currentTime.isBefore(sunInfo.sunrise)
      # fading in
      scale currentTime.unix(), sunInfo.twilightBegin.unix(), sunInfo.sunrise.unix(), 0, 255
    else if currentTime.isAfter(sunInfo.sunset)
      # fading out
      scale currentTime.unix(), sunInfo.sunset.unix(), sunInfo.twilightEnd.unix(), 255, 0
    else
      LIGHT
  .map(Math.floor)
  .skipDuplicates()

#sunBrightnessP.log()

module.exports = { sunLightInfoP, sunBrightnessP }
