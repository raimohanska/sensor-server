#!/usr/bin/env coffee
require('es6-promise').polyfill()
R = require "ramda"
log = require "./log"
B=require "baconjs"
KeenSender = require "./keen-sender"
HttpServer = require "./http-server"
Influx = require "./influx-store"
validate = require "./validate"
mapProperties = require "./property-mapping"
config = require "./config"

sensorE = HttpServer.sensorE
  .flatMap(validate)
  .map(mapProperties)

sensorE
  .onValue(KeenSender.send)

sensorE
  .onValue(Influx.store)

sensorE
  .onError (error) -> log("ERROR: " + error)

if config.init
  mods = {
    time: require("./time"),
    sun: require("./sun"),
    sensors: { sensorE },
    log
  }

  if config.houm
    mods.houm = require "./houm"

  config.init mods
