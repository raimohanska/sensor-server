const net = require('net');
const B = require('baconjs');
const R = require('ramda');
const log = require("./log");
const carrier = require("carrier");
const config = require('./read-config').tcp;
const sites = require("./sites");
const port = config != null ? config.port : undefined;
const mock = require("./mock");

const addSocketE = B.Bus();
const removeSocketE = B.Bus();
removeSocketE.map(".id").forEach(log, "TCP device disconnected");
const messageFromDeviceE = B.Bus();

const deviceConnectedE = addSocketE.map(".id");
deviceConnectedE.forEach(log, "TCP device connected");

const devicesP = B.update([],
  addSocketE, ((xs, x) => xs.concat(x)),
  removeSocketE, ((xs, x) => xs.filter((d => d.socket !== x.socket))));

const deviceIdsP = devicesP.map(devices => devices.map(({id}) => id));
deviceIdsP.log("Connected devices");

if (port != null) {
  net.createServer(function(socket) {
    log('connected', socket.remoteAddress);
    let id = null;
    const discoE = B.fromEvent(socket, 'close').take(1).map(() => (({ socket, id })));
    discoE.forEach(() => log('disconnected', socket.remoteAddress));
    const errorE = B.fromEvent(socket, 'error').log("Error reading from " + socket.remoteAddress);
    removeSocketE.plug(discoE);
    const lineE = B.fromEvent((carrier.carry(socket)), "line");
    const jsonE = lineE.flatMap(B.try(JSON.parse));
    jsonE.onError(function(err) {
      log(socket.remoteAddress,  err);
      socket.end();
    });
    jsonE.take(1).onValue(function(login) {
      if ((login.device == null)) {
        log("invalid login message", login);
        socket.end();
      } else {
        id = login.device;
        B.interval(30000).map({"ping":"ping"}).takeUntil(discoE).forEach(sendToDevice(id));
        messageFromDeviceE.push(login);
        jsonE.onValue(function(msg) {
          msg.device = id;
          log('Message from device ' + id + ": " + JSON.stringify(msg));
          messageFromDeviceE.push(msg);
        });
        addSocketE.push({id, socket});
      }});
  }).listen(port);
  log("TCP listening on port", port);
}

messageFromDeviceE
  .onValue(function(message) {
    const site = sites.findSiteByEvent(message);
    if (site != null) {
      site.devices.reportDeviceSeen(message.device);
      if (message.value != null) {
        site.sensors.pushEvent(message);
      }
    }
});

var sendToDevice = id => (function(msg) {
  if (mock) { return; }
  devicesP.take(1).onValue(function(devices) {
    devices = R.filter(R.propEq('id', id), devices);
    devices.forEach(device => device.socket.write(JSON.stringify(msg)+"\n", "utf-8"));
  });
});

module.exports = { devicesP, deviceConnectedE, sendToDevice, messageFromDeviceE };
