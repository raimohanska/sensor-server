net = require 'net'
B = require 'baconjs'
R = require 'ramda'
log = require "./log"
rp = require('request-promise')

args = process.argv.slice(2)
host = args[0] || "localhost"
port = args[1] || 5080
event = { type: "test", value: 600 }
rp({method: "post", uri: "http://" + host + ":" + port + "/event", body: event, json: true}).then ->
  console.log "posted"
