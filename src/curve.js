const B = require("baconjs");
const time = require("./time");

const parseTime = function(str) {
  const parse = s => parseInt(s) || 0;
  const [h, m, s] = Array.from(str.split(":"));
  return {
    h: parse(h),
    m: parse(m),
    s: parse(s),
    today() { return time.todayAt(this.h, this.m, this.s); },
    tomorrow() { return this.today().add(1, "day"); },
    yesterday() { return this.today().add(-1, "day"); },
    isAfter(t) { return this.today().isAfter(t); }
  };
};

Array.prototype.indexWhere = function(f) {
  for (let i = 0; i < this.length; i++) {
    const v = this[i];
    if (f(v)) { return i; }
  }
  return -1;
};

const Curve = function(points, discrete) {
  points = points.map(({time, value}) => ({
    time: parseTime(time),
    value
  }));
  return function(t) {
    let nextPoint, prevPoint;
    const nextPointIndex = points.indexWhere(p => p.time.isAfter(t));
    if (nextPointIndex < 0) {
      prevPoint = points[points.length - 1];
      prevPoint = { time: prevPoint.time.today(), value: prevPoint.value };
      nextPoint = points[0];
      nextPoint = { time: nextPoint.time.tomorrow(), value: nextPoint.value };
    } else if (nextPointIndex === 0) {
      prevPoint = points[points.length - 1];
      prevPoint = { time: prevPoint.time.yesterday(), value: prevPoint.value };
      nextPoint = points[0];
      nextPoint = { time: nextPoint.time.today(), value: nextPoint.value };
    } else {
      prevPoint = points[nextPointIndex - 1];
      prevPoint = { time: prevPoint.time.today(), value: prevPoint.value };
      nextPoint = points[nextPointIndex];
      nextPoint = { time: nextPoint.time.today(), value: nextPoint.value };
    }

    if (discrete) {
      return prevPoint.value;
    } else {
      const periodStart = prevPoint.time.toDate().getTime();
      const periodLength = nextPoint.time.toDate().getTime() - periodStart;
      const periodOffset = t.toDate().getTime() - periodStart;
      return Math.round(prevPoint.value + (((nextPoint.value - prevPoint.value) * periodOffset) / periodLength));
    }
  };
};

Curve.discreteCurveProperty = p => Curve.curveProperty(p, true);

Curve.curveProperty = (p, discrete) => B.combineTemplate({
  curve: p,
  time: time.eachSecondE
}).map(({curve, time}) => Curve(curve, discrete)(time))
  .skipDuplicates();

/*
const exampleCurve = Curve([
    { time: "0:00", value: 0 },
    { time: "15:00", value: 0 },
    { time: "17:00", value: 255 },
    { time: "19:00", value: 255 },
    { time: "19:15", value: 0 }
]);

console.log exampleCurve(time.todayAt("16:59:59"))
*/

module.exports = Curve;
