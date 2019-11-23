const scale = (inMin, inMax, outMin, outMax) => (function(value) {
  const scaled = outMin + (((value - inMin) * (outMax - outMin)) / (inMax - inMin));
  return limitBetween(scaled, outMin, outMax);
});

var limitBetween = (value, a, b) => Math.max(Math.min(value, Math.max(a, b)), Math.min(a, b));

module.exports = scale;
