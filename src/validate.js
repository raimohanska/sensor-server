const Bacon = require("baconjs");
const show = JSON.stringify;
const R = require("ramda");

const validate = function(sensorEvent) {
  if ((sensorEvent.value == null)) {
    return new Bacon.Error("value attribute missing from " + show(sensorEvent));
  } else if (R.keys(sensorEvent).length < 2) {
    return new Bacon.Error("at least 2 attributes required in " + show(sensorEvent));
  } else {
    return sensorEvent;
  }
};

module.exports = validate;
