R = require "ramda"
log = require "./log"
B=require "baconjs"
io = require('socket.io-client')

initSite = (site) ->
  sources = site.config.sourceSites || []
  sources.forEach (sourceSite) ->
    log "sourcing from", sourceSite
    socket = io(sourceSite.url)
    socket.on "connect", ->
      log "Connected to source server", sourceSite.url
      socket.emit "login", { siteId: sourceSite.siteId, siteKey: sourceSite.siteKey }
    socket.on "login-error", (error) ->
      log "Error logging into source server " + sourceSite.url + ":" + error
    socket.on "login-success", ->
      log "Logged in to source server", sourceSite.url
    socket.on "sensor-event", (event) ->
      log "Sensor event from " + sourceSite.url + " for site " + site.id, event
      site.sensors.pushEvent event

module.exports = { initSite }
