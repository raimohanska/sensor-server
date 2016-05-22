#!/usr/bin/env coffee
require "./polyfills.js"
require('es6-promise').polyfill()
R = require "ramda"
log = require "./log"
time = require "./time"
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
tcpServer = require "./tcp-server"

sensorE = sensors.sensorE

sensorE
  .onValue(KeenSender.send)

sensorE
  .repeatBy(sensors.sourceHash, time.oneHour, time.oneSecond)
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
    B,
    devices: tcpServer
  }

  if config.houm
    mods.houm = require "./houm"

  config.init mods
