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

testSite =
  config:
    latitude: 60.1695200
    longitude: 24.9354500

getSunlightInfo = (time, lat, lon) ->
  sunInfo = suncalc.getTimes(time, lat, lon)
  {
    twilightBegin: moment(sunInfo.dawn)
    sunrise: moment(sunInfo.sunrise)
    sunset: moment(sunInfo.sunset)
    twilightEnd: moment(sunInfo.dusk)
  }

getSunBrightness = (time, lat, lon) ->
  #currentTime = currentTime.subtract(11, 'h')
  currentTime = moment(time)
  sunInfo = getSunlightInfo time, lat, lon
  if currentTime.isBefore(sunInfo.twilightBegin) || currentTime.isAfter(sunInfo.twilightEnd)
    DARK
  else if currentTime.isBefore(sunInfo.sunrise)
    # fading in
    scale(sunInfo.twilightBegin.unix(), sunInfo.sunrise.unix(), 0, 255)(currentTime.unix())
  else if currentTime.isAfter(sunInfo.sunset)
    # fading out
    scale(sunInfo.sunset.unix(), sunInfo.twilightEnd.unix(), 255, 0)(currentTime.unix())
  else
    LIGHT

initSite = (site) -> 
  site = testSite if !site
  sunLightInfoP = B.once().concat(B.interval(time.oneHour))
    .map(-> getSunlightInfo(new Date(), site.config.latitude, site.config.longitude))
    .toProperty()
    .skipDuplicates(R.equals)

  sunBrightnessP = time.eachSecondE
    .map((time) -> getSunBrightness(time, site.config.latitude, site.config.longitude))
    .toProperty()
    .map(Math.floor)
    .skipDuplicates()

  { sunLightInfoP, sunBrightnessP }
module.exports = { initSite, getSunlightInfo, getSunBrightness }
