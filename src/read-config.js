const configFile = "../config.js";
try {
  module.exports = require(configFile);
} catch (e) {
  console.warn("Config file not found. Using example config.")
  module.exports = require("./example-config.js")
}
