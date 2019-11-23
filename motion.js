const time = require("./time");
const B = require("baconjs");

const initSite = function(site) {
  const motionP = location => site.sensors.sensorP({type: "motion", location}).map(x => x > 0);

  const motionStartE = location => motionP(location).changes().filter(x => x);
  const motionEndE = location => motionP(location).changes().filter(x => !x);

  const occupiedP = function(location, throttle) {
      if (throttle == null) { throttle = time.minutes(30); }
      return motionStartE(location)
        .flatMapLatest(x => B.once(x).concat(motionEndE(location).delay(throttle).map(false)))
        .toProperty(0).skipDuplicates();
    };

  const inactiveE = function(location, throttle) {
    if (throttle == null) { throttle = time.oneHour; }
    return occupiedP(location, throttle)
      .changes()
      .filter(x => !x)
      .map(location + " unoccupied for " + time.formatDuration(throttle));
  };

  const motionStartingInDarkP = (location, darkP) => motionStartE(location).filter(darkP) // liike alkaa hämärässä
    .flatMapLatest(() => B.once(true).concat(motionEndE(location).map(false)))
    .toProperty(false);

  return {occupiedP, motionStartE, motionEndE, motionP, inactiveE, motionStartingInDarkP};
};

module.exports = { initSite };
