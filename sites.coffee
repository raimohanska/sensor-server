B = require 'baconjs'
R = require 'ramda'
log = require "./log"
config = require "./read-config"

sites = {}

registerSite = (siteId, site) ->
  log "register site", siteId
  sites[siteId] = site

findSiteByEvent = (event) ->
  siteId = event.siteId || "default"
  site = sites[siteId]
  if !site?
    log "Unknown site " + siteId + " in ", JSON.stringify(event)
    null
  else if (event.siteKey != site.config.siteKey)
    log "Site key mismatch for site " + siteId + " in ", JSON.stringify(event)
    null
  else
    site

module.exports = { findSiteByEvent, registerSite }
