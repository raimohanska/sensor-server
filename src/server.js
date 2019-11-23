#!/usr/bin/env node

require("./polyfills.js");

const mock = require("./mock");
if (mock) { console.log("Mocking output"); }
const R = require("ramda");
const log = require("./log");
const time = require("./time");
log("Starting");
const B=require("baconjs");
require("./bacon-extensions");
const HttpServer = require("./http-server");
const influx = require("./influx-store");
const config = require("./read-config");
const sensors = require("./sensors");
const houm3 = require("./houm3");
const devices = require("./devices");
const sites = require("./sites");
const motion = require("./motion");
const siteConfigs = R.toPairs(config.sites);
const mail = require("./mail");
const sourcing = require("./sourcing-client");
const sun = require("./sun");
const intertechno = require("./intertechno");

siteConfigs.forEach(function(...args) {
  const [siteId, siteConfig] = Array.from(args[0]);
  const site = {
    id: siteId,
    config: siteConfig,
    time: require("./time"),
    curve: require("./curve"),
    log,
    R,
    B
  };

  site.sun = sun.initSite(site);
  site.mail = mail.initSite(site);
  site.sensors = sensors.initSite(site);
  site.devices = devices.initSite(site);
  site.houm = houm3.initSite(site);
  site.motion = motion.initSite(site);
  site.influx = influx.initSite(site);
  site.intertechno = intertechno.initSite(site);
  HttpServer.initSite(site);

  sites.registerSite(siteId, site);

  const {
    sensorE
  } = site.sensors;
  sensorE
    .repeatBy(site.sensors.sourceHash, time.oneHour, { throttle: time.oneSecond, maxRepeat: time.oneDay})
    .onValue(site.influx.store);

  sensorE
    .onError(error => log("ERROR: " + error));

  sourcing.initSite(site);

  if (siteConfig.init) {
    return siteConfig.init(site);
  }
});
