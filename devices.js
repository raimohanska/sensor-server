const B = require('baconjs');
require('./bacon-extensions');
const R = require('ramda');
const L = require('partial.lenses');
const time = require('./time');
const log = require("./log");
const carrier = require("carrier");

const initSite = function(site) { 
  const siteConfig = site.config;
  const devices = siteConfig.devices || {};
  const initialDevicesStatii = R.fromPairs(R.keys(devices).map(key => [key, {}]));
  const started = time.now();
  const deviceSeenE = B.Bus();

  const updateDeviceSeen = (deviceStatii, key) => L.set(L.compose(key, "lastSeen"), time.now().toString(), deviceStatii);

  const devicesStatusP = B.update(
    initialDevicesStatii,
    [deviceSeenE], updateDeviceSeen
  );

  const timeSinceSeenDevicesP = devicesStatusP.sampledBy(time.eachSecondE)
    .toProperty()
    .map(statii => mapValues(value => calcAge(value.lastSeen))(statii));

  timeSinceSeenDevicesP
    .sample(time.oneHour)
    .flatMap(function(statii) {
      const events = R.toPairs(statii).map(function(...args) { const [device, value] = Array.from(args[0]); return { type: "delay", device, value }; });
      return B.fromArray(events);})
    .filter(".value")
    .forEach(site.sensors.pushEvent);

  const missingDevicesP = timeSinceSeenDevicesP
    .map(function(statii) {
      const ages = mapValues((age, key) => (age || calcAge(started)) > (devices[key] != null ? devices[key].offlineDelay : undefined))(statii);
      const filtered=filterValues(R.identity)(ages);
      return R.keys(filtered);})
    .skipDuplicates(R.equals);

  missingDevicesP.filter(".length").forEach(function(missing) {
    const names = missing.map(d => (devices[d] != null ? devices[d].name : undefined) || d);
    const text = "Following devices seem to have gone offline: " + names.join(",");
    return site.mail.send(missing.length + " devices offline", text);
  });

  var mapValues = f => obj => R.fromPairs(R.toPairs(obj).map(function(...args) { const [key, value] = Array.from(args[0]); return [key, f(value, key)]; }));

  var filterValues = f => obj => R.fromPairs(R.toPairs(obj).filter(function(...args) { const [key, value] = Array.from(args[0]); return f(value, key); }));

  var calcAge = function(t) { if (t != null) { 
    return time.now().diff(t);
  } };

  devicesStatusP.throttle(time.minutes(10)).log("deviceStatus");

  const reportDeviceSeen = function(key) { if (key != null) {
    deviceSeenE.push(key);
  } };

  const siteApi = { reportDeviceSeen };
  return siteApi;
};

module.exports = { initSite };
