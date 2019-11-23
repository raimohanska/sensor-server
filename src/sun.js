const R = require("ramda");
const B=require("baconjs");
const moment=require("moment");
const time = require("./time");
const scale = require("./scale");
const suncalc = require("suncalc");

const LIGHT = 255;
const DARK = 0;

const testSite = {
  config: {
    latitude: 60.1695200,
    longitude: 24.9354500
  }
};

const getSunlightInfo = function(time, lat, lon) {
  const sunInfo = suncalc.getTimes(time, lat, lon);
  return {
    twilightBegin: moment(sunInfo.dawn),
    sunrise: moment(sunInfo.sunrise),
    sunset: moment(sunInfo.sunset),
    twilightEnd: moment(sunInfo.dusk)
  };
};

const getSunBrightness = function(time, lat, lon) {
  //currentTime = currentTime.subtract(11, 'h')
  const currentTime = moment(time);
  const sunInfo = getSunlightInfo(time, lat, lon);
  if (currentTime.isBefore(sunInfo.twilightBegin) || currentTime.isAfter(sunInfo.twilightEnd)) {
    return DARK;
  } else if (currentTime.isBefore(sunInfo.sunrise)) {
    // fading in
    return scale(sunInfo.twilightBegin.unix(), sunInfo.sunrise.unix(), 0, 255)(currentTime.unix());
  } else if (currentTime.isAfter(sunInfo.sunset)) {
    // fading out
    return scale(sunInfo.sunset.unix(), sunInfo.twilightEnd.unix(), 255, 0)(currentTime.unix());
  } else {
    return LIGHT;
  }
};

const initSite = function(site) { 
  if (!site) { site = testSite; }
  const sunLightInfoP = B.once().concat(B.interval(time.oneHour))
    .map(() => getSunlightInfo(new Date(), site.config.latitude, site.config.longitude))
    .toProperty()
    .skipDuplicates(R.equals);

  const sunBrightnessP = time.eachSecondE
    .map(time => getSunBrightness(time, site.config.latitude, site.config.longitude))
    .toProperty()
    .map(Math.floor)
    .skipDuplicates();

  return { sunLightInfoP, sunBrightnessP };
};
module.exports = { initSite, getSunlightInfo, getSunBrightness };
