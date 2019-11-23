const B=require("baconjs");
let log=require("./log");
const {
  exec
} = require('child_process');

const pingE = function(hostname, options) {
  if (options == null) { options = {}; }
  const interval = options.interval || 1000;
  const ping = function() {
    const ps = exec("ping -c 1 " + hostname + " -W 1");
    return B.fromEvent(ps, "exit").take(1).delay(interval);
  };
  log = function() { return console.log.apply(console, [new Date()].concat(Array.prototype.slice.call(arguments))); };
  return B.repeat(ping).map(exitCode => exitCode === 0);
};

const hostDownE = function(hostname, options) {
  if (options == null) { options = {}; }
  const downCount = options.downCount || 10;
  const ping = pingE(hostname, options);
  const pingSuccessE = ping.filter(x => x);
  const pingFailE = ping.filter(x => !x);
  const tenConsecutiveFails = () => pingSuccessE.take(1).filter(false) // wait for first success
  .concat(pingFailE.take(1).filter(false)) // wait for first failure
  .concat(pingFailE.take(downCount - 1).doAction(log, "ping fail: " + hostname).last().takeUntil(pingSuccessE.doAction(log, "ping ok: " + hostname)));
  return B.repeat(tenConsecutiveFails);
};
 
module.exports = { hostDownE, pingE };
