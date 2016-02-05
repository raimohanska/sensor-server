scale = (value, inMin, inMax, outMin, outMax) ->
  if value < inMin
    outMin
  else if value > inMax
    outMax
  else
    outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin)

module.exports = scale
