const log = require("./log");
const io = require('socket.io-client');

const initSite = function(site) {
  const sources = site.config.sourceSites || [];
  sources.forEach(function(sourceSite) {
    log("sourcing from", sourceSite);
    const socket = io(sourceSite.url);
    socket.on("connect", function() {
      log("Connected to source server", sourceSite.url);
      socket.emit("login", { siteId: sourceSite.siteId, siteKey: sourceSite.siteKey });
  });
    socket.on("disconnect", () => log("Disconnected from source server", sourceSite.url));
    socket.on("login-error", error => log("Error logging into source server " + sourceSite.url + ":" + error));
    socket.on("login-success", () => log("Logged in to source server", sourceSite.url));
    return socket.on("sensor-event", function(event) {
      log("Sensor event from " + sourceSite.url + " for site " + site.id, event);
      site.sensors.pushEvent(event);
    });
  });
};

module.exports = { initSite };
