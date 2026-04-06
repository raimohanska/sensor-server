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
const influx = require("./influx-store");
const config = require("./read-config");
const sensors = require("./sensors");
const houm3 = require("./houm3");
const devices = require("./devices");
const sites = require("./sites");
const motion = require("./motion");
const siteConfigs = R.toPairs(config.sites);
const mail = require("./mail");
const sun = require("./sun");
const intertechno = require("./intertechno");
const S2M = require("./sensor-to-mqtt.js")

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
  
  sites.registerSite(siteId, site);

  const {
    sensorE
  } = site.sensors;
  sensorE
    .repeatBy(site.sensors.sourceHash, time.oneHour, { throttle: time.oneSecond, maxRepeat: time.oneDay})
    .onValue(site.influx.store);

  if (siteConfig.mqtt) {
    S2M.init(siteConfig.mqtt)
    Object.entries(siteConfig.devices).forEach(([deviceId, deviceConfig]) => {
      if (deviceConfig.properties.lightId) {
        S2M.publishMqttLight(deviceId, deviceConfig.properties)
      }      
    })
    sensorE.onValue(S2M.sendToMqtt)
  }  
  
  sensorE
    .onError(error => log("ERROR: " + error));

  if (siteConfig.init) {
    return siteConfig.init(site);
  }
});
