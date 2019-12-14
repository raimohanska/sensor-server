const bodyParser = require("body-parser");

const textParser = bodyParser.text({type: "application/json"});
const jsonParser = (req, res, next) => {
  function myNext(e) {
    if (e) {
      next(e)
    } else {      
      try {
        req.body = JSON.parse(req.body)
        next()
      } catch (e) {
        const ip = req.headers['x-forwarded-for'] || req.connection.remoteAddress;
        console.error("Error parsing JSON from " + ip + ": " + e + " body = " + req.body)
        res.status(400)
        res.send("Invalid JSON")
      }
    }
  }
  textParser(req, res, myNext)
}
module.exports = jsonParser