const log = require("./log");
const R=require("ramda");
const B=require("baconjs");
const time=require("./time");
const Influx=require("influx");
const mock = require("./mock");

var https = require("https");
var url = require("url");

const initSite = function(site) {
  let store;
  const config = site.config.influx;
  if (config && !mock) {
    const client = new Influx.InfluxDB(config);

    log("Connecting to InfluxDB at " + config.protocol + "://" + config.host + ":" + config.port + "/" + config.database);
    const eventBus = B.Bus();
      
    store = function(event) {
      //console.log("Store event to influx: " + JSON.stringify(event))
      eventBus.push(event);
    };
      
    const resultE = eventBus.flatMap(function(influxEvent) {
      return B.fromPromise(writeEvent(influxEvent));
    });
    const errorE = resultE.errors().mapError(B._.id);
    errorE.debounceImmediate(time.oneHour).onValue(err => log("Influx storage error: " + err.stack.split("\n")));
    const inErrorP = errorE.awaiting(resultE.skipErrors()).hasMaintainedValueForPeriod(true, time.oneSecond);
    inErrorP.debounce(time.oneHour).changes().onValue(function(error) {
      if (error) {
        site.mail.send("Influx storage error", "Couldn't save event to the Influx Database");
      }
    });

    return { store };
  } else {
    return { store() {} };
  }

	function request(path, options, body) {
		return new Promise(function (resolve, reject) {
			var parsed = url.parse(config.url + path);
			options.hostname = parsed.hostname;
			options.port = parsed.port;
			options.path = parsed.path;
			var req = https.request(options, function (res) {
				var chunks = [];
				res.on("data", function (chunk) { chunks.push(chunk); });
				res.on("end", function () {
					resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString() });
				});
			});
			req.on("error", reject);
			if (body) req.write(body);
			req.end();
		});
	}


	// Convert a JSON event like {"type":"motion","value":0,"device":"raimo-unit-6"}
	// into InfluxDB line protocol: motion,device=raimo-unit-6 value=0 <timestamp>
	// "type" becomes the measurement, "value" becomes the field, everything else becomes tags.
	function eventToLineProtocol(event) {
		var measurement = event.type;
		var value = event.value;
		var tags = [];

		Object.keys(event).forEach(function (key) {
			if (key === "type" || key === "value") return;
			if (typeof event[key] !== "string") return;
			var v = event[key].replace(/ /g, "\\ ").replace(/,/g, "\\,");
			tags.push(key + "=" + v);
		});

		var tagStr = tags.length > 0 ? "," + tags.join(",") : "";
		var timestamp = Date.now() + "000000"; // nanoseconds

		return measurement + tagStr + " value=" + value + " " + timestamp;
	}

	function writeEvent(event) {
		//console.log("Going to write to Influx " + JSON.stringify(event))
		var line = eventToLineProtocol(event);
		//console.log("LINE: " + line)
		return request(
			"/api/v2/write?org=" + config.org + "&bucket=" + config.bucket + "&precision=ns",
			{
				method: "POST",
				headers: {
					Authorization: "Token " + config.token,
					"Content-Type": "text/plain",
				},
			},
			line
		).then(function (res) {
			if (res.status === 204) {
				return;
			}
			throw new Error("Write failed (" + res.status + "): " + res.body);
		}).catch(function(err) {
			 console.error("Failed to write event", err)
		});
	}
};

module.exports = { initSite };
