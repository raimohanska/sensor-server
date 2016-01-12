B=require "baconjs"

log = (msg...) ->
  console.log new Date(), msg...

module.exports = log

B.Observable :: log = (msg ...) ->
  this.forEach (value) ->
    log(msg..., value)
  this
