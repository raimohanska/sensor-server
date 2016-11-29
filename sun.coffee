R = require "ramda"
log = require "./log"
B=require "baconjs"
moment=require "moment"
time = require "./time"
scale = require "./scale"
suncalc = require "suncalc"

parseTime = (str) -> 
  moment(str + " +0000", "h:mm:ss A Z")

LIGHT = 255
DARK = 0

initSite = (site) -> 
  sunLightInfoP = B.once().concat(B.interval(time.oneHour))
    .map(-> suncalc.getTimes(new Date(), site.config.latitude, site.config.longitude))
    .toProperty()
    .skipDuplicates(R.equals)
    .map (sunInfo) ->
      {
        twilightBegin: moment(sunInfo.dawn)
        sunrise: moment(sunInfo.sunrise)
        sunset: moment(sunInfo.sunset)
        twilightEnd: moment(sunInfo.dusk)
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

  { sunLightInfoP, sunBrightnessP }
module.exports = { initSite }
