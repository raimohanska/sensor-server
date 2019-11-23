const B = require("baconjs");
const scale = require("./scale");
const store = require("./store")("latest-values");

B.range = (start, end, interval) => B.repeat(function(i) {
  const next = i + start;
  if (next < end) {
    return B.later(interval, next);
  } else {
    return false;
  }
});

B.Observable .prototype. withLatestFrom = function(other, f) {
  return other.sampledBy(this, (v2, v1) => f(v1, v2));
};

B.Observable .prototype. repeatBy = function(keyF, interval, {throttle, maxRepeat}) {
  const src = this;
  return src
    .flatMap(function(event) {
      const key = keyF(event);
      let keyEvents = B.once(event)
        .concat(B.interval(interval, event)
          .takeUntil(src.filter(e => keyF(e) === key)));
      if (throttle != null) {
        keyEvents = keyEvents.throttle(throttle);
      }
      if (maxRepeat != null) {
        keyEvents = keyEvents.takeUntil(B.later(maxRepeat));
      }
      return keyEvents;
  });
};

B.Observable .prototype. repeatLatest = function(interval) {
  return this.flatMapLatest(value => B.once(value).concat(B.interval(interval, value)));
};

B.Property .prototype. isBelowWithHysteresis = function(lowLimit, highLimit) {
  const state = B.combineTemplate({ lowLimit, highLimit, value: this });
  return state
    .scan(false, function(prev, {lowLimit, highLimit, value}) {
      if (prev) {
        return value < highLimit;
      } else {
        return value < lowLimit;
      }
  }).skipDuplicates();
};

B.fade = function(from, to, fadeStepTime, fadeStep) {
  if (fadeStepTime == null) { fadeStepTime = 100; }
  if (fadeStep == null) { fadeStep = 0.1; }
  const diff = (to - from) / fadeStep;
  const steps = Math.floor(Math.abs(diff));
  if ((from === undefined) || (steps === 0)) {
    //log "set to", to
    return B.once(to);
  } else {
    //log "fade from", from, "to", to, "in", steps, " steps"
    return B.range(0, steps, fadeStepTime)
      .map(step => scale(0, steps, from, to)(step + 1)).concat(B.once(to));
  }
};

B.Property .prototype. persist = function(key, shouldLog) {
  if (shouldLog == null) { shouldLog = true; }
  const startValueP = store.read(key);
  this.changes().forEach(value => store.write(key, value));
  const data = startValueP.toEventStream().concat(this).toProperty().skipDuplicates();
  if (shouldLog) { return data.log(key); } else { return data; }
};

B.Property .prototype. smooth = function(param) {
  if (param == null) { param = {stepTime: 100, step: 0.1}; }
  const {stepTime, step} = param;
  const src = this;
  let value = undefined;
  return src
    .flatMapLatest(newValue => B.fade(value, newValue, stepTime, step)
    .map(function(newValue) {
      value = newValue;
      return value;
  })).toProperty()
    .skipDuplicates();
};

B.Property .prototype. combineWithHistory = function(delay, combinator) {
  return this
    .delay(delay)
    .combine(this, combinator)
    .skipDuplicates();
};

B.Property .prototype. hasMaintainedValueForPeriod = function(value, period) {
  return this
    .skipDuplicates()
    .flatMapLatest(function(x) {
      if (x === value) {
        return B.once(false).concat(B.later(period, true));
      } else {
        return false;
      }}).startWith(false)
    .skipDuplicates();
};
