const R = require("ramda");
const log = require("./log");
const time = require("./time");
const B = require("baconjs");

let sender = null;
const getSender = function(config) {
  let pin;
  if (!sender) {
    const itConfig = config.intertechno;
    pin = itConfig.transmitPin;
    log("init intertechno for pin " + pin);
    sender =  (() => { try {
      return require('node-intertechno-sender'); // May throw an error if /dev/gpiomem is not accessible
    } catch (e) {
      log("Module node-intertechno-sender not installed, using mock Intertechno interface");
      return {
        enableTransmit() {},
        setRepeatTransmit() {},
        setState(id, state) { return log("Pretending to send " + id + "=" + state + " on pin " + pin); }
      };
    } })();
    sender.enableTransmit(pin);
    sender.setRepeatTransmit(5);
  }
  return sender;
};

const commandBus = new B.Bus()
commandBus.bufferingThrottle(time.oneSecond).forEach(({itId, state}) => {
  sender.setState(itId, state);
})

const initSite = function(site) {
  const itConfig = site.config.intertechno;
  if (!itConfig) {
    return null;
  }
  sender = getSender(site.config);
  if (site.houm) {
    return R.values(site.config.devices)
      .filter(d => ((d.properties != null ? d.properties.intertechnoId : undefined) >= 0) && d.properties.lightId)
      .forEach(function(d) {
        const {
          lightId
        } = d.properties;
        const itId = d.properties.intertechnoId;
        log("Mapping light " + lightId + " to Intertechno id " + itId);
        const brightnessP = site.houm.lightStateP(lightId).map('.value');
        return brightnessP.repeatLatest(time.oneMinute * 15).forEach(function(bri) {
          const state = bri > 0;
          log("Intertechno " + itId + " state=" + state);
          commandBus.push({itId, state});          
        });
    });
  }
};

commandBus.onValue(({itId, state}) => {
  sender.setState(itId, state);
})

module.exports = { initSite, getSender };
