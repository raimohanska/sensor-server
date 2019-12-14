const B=require("baconjs");
let log=require("./log");
const ping = require("ping");
const {
  exec
} = require('child_process');

function silence(duration) {
  return B.later(duration).filter(false)
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
 
module.exports = { hostDownE, pingE };
