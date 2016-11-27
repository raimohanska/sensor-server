configFile = process.env.SENSOR_SERVER_CONFIG || "./config"
config = require configFile
module.exports = config
