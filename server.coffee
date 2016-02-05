#!/usr/bin/env coffee
require('es6-promise').polyfill()
R = require "ramda"
log = require "./log"
log "Starting"
B=require "baconjs"
require "./bacon-extensions"
KeenSender = require "./keen-sender"
HttpServer = require "./http-server"
Influx = require "./influx-store"
validate = require "./validate"
mapProperties = require "./property-mapping"
config = require "./config"
sensors = require "./sensors"

sensorE = sensors.sensorE

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
    motion: require("./motion"),
    sensors,
    log,
    R,
    B
  }

  if config.houm
    mods.houm = require "./houm"

  config.init mods
