const log = require("./log");

const initSite = function(site) {
  let send;
  const config = site.config.mailgun;
  if (config != null) {
    const mailgun = require('mailgun-js')({
      apiKey: config.apiKey,
      domain: config.domain});
    send = function(subject, text) {
      const data = {
        from: config.from,
        to: config.to,
        subject,
        text
      };
      return mailgun.messages().send(data, function(error, body) {
        if (error) {
          return log("Error sending mail", error);
        } else {
          return log("Sent mail", subject, text);
        }
      });
    };
    return { send };
  } else {
    return {
      send(subject, text) { return log("Pretending to send", subject, text); }
    };
  }
};

module.exports = { initSite };
