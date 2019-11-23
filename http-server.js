const R = require("ramda");
const express = require("express");
const app = express();
const http = require('http').Server(app);
const io = require('socket.io')(http);
const log = require("./log");
const bodyParser = require("body-parser");
const devices = require("./devices");
const sites = require("./sites");
const Bacon = require("baconjs");
const config = require("./read-config");

const port = process.env.PORT || (config.http != null ? config.http.port : undefined) || 5080;

const jsonParser = bodyParser.json();

const sensorE = Bacon.Bus();

const initSite = function(site) {
  if ((site.config.web != null) && site.config.siteKey) {
    console.log("Setting up web ui for site " + site.config.siteKey);
    app.get("/site/" + site.config.siteKey + "/ui/state", function(req, res) {
      res.setHeader('Content-Type', 'application/json');
      const values = R.fromPairs(site.config.web.components.map(c => [c.valueKey, c.defaultValue]));
      // TODO: merge current values, store values
      res.send(JSON.stringify(R.merge(site.config.web, { values })));
    });
    app.post("/site/" + site.config.siteKey + "/ui/values", jsonParser, function(req, res) {
      console.log(req.body);
      R.toPairs(req.body).forEach((...args) => {
        const [key, value] = Array.from(args[0]);
        const component = site.config.web.components
          .find(component => component.valueKey === key);
        const event = R.merge({ value, siteKey: site.config.siteKey }, component.properties);
        sensorE.push(event);
      });
    });

    app.use("/site/" + site.config.siteKey + "/", express.static("client/dist"));
  }
};

app.post("/event", jsonParser, function(req, res) {
  const events = req.body instanceof Array ?
    req.body
  :
    [req.body];
  events.forEach(event => sensorE.push(event));
  res.send("ok");
});

http.listen(port, () => log("HTTP listening on port", port));

sensorE.onValue(function(event) {
  const site = sites.findSiteByEvent(event);
  if (site != null) {
    log("HTTP sersor event", JSON.stringify(event));
    site.devices.reportDeviceSeen(event.device);
    site.sensors.pushEvent(event);
  }
});

io.on("connection", socket => socket.on("login", function(login) {
  const error = function(msg) {
    log(msg, "from", login);
    socket.emit("login-error", msg);
  };
  if ((login.siteId == null)) {
    error("siteId missing");
  } else {
    const site = sites.findSiteByEvent(login);
    if ((site == null)) {
      error("invalid siteId/siteKey");
    } else {
      log("Sourcing server logged in for site " + login.siteId + " at " + socket.conn.remoteAddress);
      socket.emit("login-success", "welcome");
      const discoE = Bacon.fromEvent(socket, "disconnect");
      discoE.forEach(() => log("Sourcing server disconnected for site " + login.siteId + " at " + socket.conn.remoteAddress));
      site.sensors.sensorE.takeUntil(discoE).forEach(event => socket.emit("sensor-event", event));
    }
  }
}));

module.exports = { sensorE, initSite };
