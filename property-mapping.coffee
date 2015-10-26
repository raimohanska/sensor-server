log = require "./log"
mappings = (require "./config").propertyMapping||{}
R = require "ramda"

mapProperties = (event) ->
  mapped = R.find(({match}) -> R.whereEq(match)(event))(mappings)
  if mapped
    event=R.merge(event, mapped.properties)
  event

module.exports = mapProperties
