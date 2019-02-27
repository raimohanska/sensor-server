#! /usr/bin/env coffee
houm = require "./houm3"
siteKey = process.env.HOUMIO_SITEKEY
args = process.argv
cmd = args[2]
fail = (msg) ->
  console.error msg
  process.exit 1
exit = ->
  process.exit 0
doHoum = (f) ->
  site = {
    config: {
      houm3: { siteKey }
    }
  }
  f(houm.initSite site)
if !siteKey?
  fail "HOUM_SITEKEY environment variable missing"

if cmd == "set" && args.length == 5
  light = args[3]
  targetValue = parseInt(args[4])
  doHoum (houm) -> 
    houm.lightStateP(light)
      .filter(({value}) -> value == targetValue)
      .onValue(exit)
    houm.setLight(light)(targetValue)
else
  fail("""
Usage: houm-cli set [light] [value]
""")
