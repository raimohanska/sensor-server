B=require "baconjs"

log = (msg...) ->
  console.log new Date(), msg...
  msg[msg.length - 1]

module.exports = log

B.Observable :: log = (msg ...) ->
  this.forEach (value) ->
    log(msg..., value)
  this
