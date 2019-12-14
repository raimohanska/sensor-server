const B=require("baconjs");
let log=require("./log");
const ping = require("ping");

function silence(duration) {
  return B.later(duration).filter(false)
}

function storePing(hostname, interval, influx) {
  pingE(hostname, { interval })
  .forEach(p => {
    const value = p.alive ? p.time : -1
    log("Ping", hostname, value)
    influx.store({type: "ping", host: hostname, value })
  });
}

const pingE = function(hostname, options) {
  if (options == null) { options = {}; }
  const interval = options.interval || 1000;
  const mkPing = function() {
    return B.fromPromise(ping.promise.probe(hostname)).concat(silence(interval))
  };
  return B.repeat(mkPing)
};

const hostDownE = function(hostname, options) {
  if (options == null) { options = {}; }
  const downCount = options.downCount || 10;
  const ping = pingE(hostname, options).map(p => p.alive)
  const pingSuccessE = ping.filter(x => x);
  const pingFailE = ping.filter(x => !x);
  const tenConsecutiveFails = () => pingSuccessE.take(1).doAction(log, "ping ok: " + hostname).filter(false) // wait for first success
  .concat(pingFailE.take(1).filter(false)) // wait for first failure
  .concat(pingFailE.take(downCount - 1).doAction(log, "ping fail: " + hostname).last().map("Host down: " + hostname).takeUntil(pingSuccessE));
  return B.repeat(tenConsecutiveFails);
};

//hostDownE("192.168.1.1", { downCount: 2 } ).log()
 
module.exports = { hostDownE, pingE, storePing };
