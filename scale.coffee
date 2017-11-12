scale = (inMin, inMax, outMin, outMax) -> (value) ->
  scaled = outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin)
  limitBetween(scaled, outMin, outMax)

limitBetween = (value, a, b) ->
  Math.max(Math.min(value, Math.max(a, b)), Math.min(a, b))

module.exports = scale
