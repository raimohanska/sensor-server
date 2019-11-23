const process = require("process")
const configFile = process.env.SENSOR_SERVER_CONFIG || "../config";
const config = require(configFile);
module.exports = config;
