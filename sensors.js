const R = require("ramda");
const log = require("./log");
const B=require("baconjs");
const validate = require("./validate");

const initSite = function(site) {
  const devices = site.config.devices || {};

  const mapProperties = function(event) {
    const device = devices[event.device];
    if (device != null) {
      const properties = device.properties || {};
      const sensorProperties = (device.sensors != null ? device.sensors[event.sensor] : undefined) || {};
      return R.mergeAll([event, properties, sensorProperties]);
    } else {
      return event;
    }
  };

  const eventBus = B.Bus();

  const sensorE = eventBus
    .flatMap(validate)
    .map(mapProperties);

  const pushEvent = eventBus.push.bind(eventBus);

  const sensorP = props => sensorE.filter(R.whereEq(props)).map(".value").toProperty();

  const sourceHash = event => R.join('')(R.chain(
    (function(...args) {
      const [k,v] = Array.from(args[0]);
      if ((k === "value") || (typeof v === "object")) { return []; } else { return [k+v]; }
    }),
    R.toPairs(event)));

  return { sensorE, sensorP, pushEvent, sourceHash };
};

module.exports = { initSite };
