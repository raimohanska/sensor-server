const log = require("./log");
const R=require("ramda");
const B=require("baconjs");
const time=require("./time");
const Influx=require("influx");
const mock = require("./mock");

const initSite = function(site) {
  let store;
  const config = site.config.influx;
  if (config && !mock) {
    const client = new Influx.InfluxDB(config);

    log("Connecting to InfluxDB at " + config.protocol + "://" + config.host + ":" + config.port + "/" + config.database);
    const eventBus = B.Bus();
      
    store = function(event) {
      const influxEvent = {
        key: event.type,
        tags: R.fromPairs(R.toPairs(event).filter(function(...args) {
          const [key, value] = Array.from(args[0]);
          return !R.contains(key)(["type", "value", "timestamp"]) && (typeof value !== "object");
        })),
        fields: {
          value: event.value
        }
      };
      if (event.timestamp) {
        influxEvent.timestamp = new Date(event.timestamp);
      }
      //log "storing to InfluxDB", JSON.stringify(influxEvent)
      eventBus.push(influxEvent);
    };
      
    const resultE = eventBus.flatMap(function(influxEvent) {
      const point = {measurement: influxEvent.key, fields: influxEvent.fields, tags: influxEvent.tags, timestamp: influxEvent.timestamp};
      return B.fromPromise(client.writePoints([point]));
    });
    const errorE = resultE.errors().mapError(B._.id);
    errorE.debounceImmediate(time.oneHour).onValue(err => log("Influx storage error: " + err.stack.split("\n")));
    const inErrorP = errorE.awaiting(resultE.skipErrors()).hasMaintainedValueForPeriod(true, time.oneSecond);
    inErrorP.skipDuplicates().debounce(time.oneHour).changes().onValue(function(error) {
      if (error) {
        site.mail.send("Influx storage error", "Couldn't save event to the Influx Database");
      } else {
        site.mail.send("Influx storage OK", "Influx storage seems to be up again");
      }
    });

    return { store };
  } else {
    return { store() {} };
  }
};

module.exports = { initSite };
