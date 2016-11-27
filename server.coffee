#!/usr/bin/env coffee
require "./polyfills.js"
require('es6-promise').polyfill()
R = require "ramda"
log = require "./log"
time = require "./time"
log "Starting"
B=require "baconjs"
require "./bacon-extensions"
HttpServer = require "./http-server"
influx = require "./influx-store"
validate = require "./validate"
configFile = process.env.SENSOR_SERVER_CONFIG || "./config"
config = require configFile
sensors = require "./sensors"
tcpServer = require "./tcp-server"
houm = require "./houm"
devices = require "./devices"
sites = require "./sites"
motion = require "./motion"
siteConfigs = R.toPairs(config.sites)
mail = require "./mail"

siteConfigs.forEach ([siteId, siteConfig]) ->
  site = { 
    config: siteConfig
    time: require("./time")
    sun: require("./sun")
    log
    R
    B
  }

  site.mail = mail.initSite site
  site.sensors = sensors.initSite site
  site.devices = devices.initSite site
  site.houm = houm.initSite site
  site.motion = motion.initSite site
  site.influx = influx.initSite site

  sites.registerSite(siteId, site)

  sensorE = site.sensors.sensorE
  sensorE
    .repeatBy(site.sensors.sourceHash, time.oneHour, { throttle: time.oneSecond, maxRepeat: time.oneDay})
    .onValue(site.influx.store)

  sensorE
    .onError (error) -> log("ERROR: " + error)

  if siteConfig.init
    siteConfig.init site
