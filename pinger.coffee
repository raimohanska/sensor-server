B=require "baconjs"
log=require "./log"
exec = require('child_process').exec

pingE = (hostname, options = {}) ->
  interval = options.interval || 1000
  ping = ->
    ps = exec "ping -c 1 " + hostname + " -W 1"
    B.fromEvent(ps, "exit").take(1).delay(interval)
  log = -> console.log.apply(console, [new Date()].concat(Array::slice.call(arguments)))
  B.repeat(ping).map((exitCode) -> exitCode == 0)

hostDownE = (hostname, options = {}) ->
  downCount = options.downCount || 10
  ping = pingE(hostname, options)
  pingSuccessE = ping.filter((x) -> x)
  pingFailE = ping.filter((x) -> !x)
  tenConsecutiveFails = ->
    pingSuccessE.take(1).filter(false) # wait for first success
    .concat(pingFailE.take(1).filter(false)) # wait for first failure
    .concat(pingFailE.take(downCount - 1).doAction(log, "ping fail: " + hostname).last().takeUntil(pingSuccessE.doAction(log, "ping ok: " + hostname)))
  B.repeat(tenConsecutiveFails)
 
module.exports = { hostDownE, pingE }
