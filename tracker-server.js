const net = require('net');
const B = require('baconjs');
const R = require('ramda');
const log = require("./log");
const carrier = require("carrier");
const config = require('./read-config').trackerServer;
const {
  sites
} = require("./sites");
const port = config != null ? config.port : undefined;


const parseTrackerInfo = function(s) {
  const lat = s.substring(24,33);
  const lon = s.substring(35,44);
  const serial = s.substring(1, 17);
  const speed = Number.parseFloat(s.substring(45, 50));
  const course = Number.parseFloat(s.substring(56, 62));
  const positioningType = s.substring(23, 24);
  const hasGpsFix = positioningType === 'A';
  
  return { lat: strToCoord(lat), lon: strToCoord(lon), speed, course, serial, hasGpsFix, raw: s };
};

const siteBySerial = function(serial) {
  const matching = function(site) { 
    const trackers = site.config.trackerServer != null ? site.config.trackerServer.trackers : undefined;
    return trackers && trackers.some(tracker => tracker.serial === serial);
  };
  return R.find(matching)(R.values(sites));
};

var strToCoord = function(str) {
  const num = Number.parseFloat(str.substring(0, 2));
  return num + (Number.parseFloat(str.substring(2)) / 60.0);
};

if (port != null) {
  net.createServer(function(socket) {
    log('connected', socket.remoteAddress);
    const id = null;
    const discoE = B.fromEvent(socket, 'close').take(1).map(() => (({ socket, id })));
    discoE.forEach(() => log('disconnected', socket.remoteAddress));
    const errorE = B.fromEvent(socket, 'error').log("Error reading from " + socket.remoteAddress);
    const chars = B.fromEvent(socket, 'data')
      .flatMap(buffer => B.fromArray(Array.prototype.slice.call(buffer, 0)))
      .map(String.fromCharCode);
    chars
      .filter(b => b === '(')
      .flatMapFirst(b => chars
         .takeWhile(b => b !== ')')
         .fold('', (soFar, next) => soFar + next)).map(str => '(' + str + ')')
      .map(parseTrackerInfo)
      .onValue(function({lat, lon, speed, course, hasGpsFix, serial, raw}) {
        const site = siteBySerial(serial);
        if ((site == null)) {
          return log("Site not found for tracker", serial);
        } else {
          log("Got tracker info from", serial, raw, {lat, lon, speed, course});
          site.sensors.pushEvent({ type: 'latitude', value: lat, serial, hasGpsFix });
          site.sensors.pushEvent({ type: 'longitude', value: lon, serial, hasGpsFix });
          site.sensors.pushEvent({ type: 'speed', value: speed, serial, hasGpsFix });
          return site.sensors.pushEvent({ type: 'course', value: course, serial, hasGpsFix });
        }});

  }).listen(port);
  log("Tracker Server listening on port", port);
}
