log = require "./log"

initSite = (site) ->
  config = site.config.mailgun
  if config?
    mailgun = require('mailgun-js')(
      apiKey: config.apiKey
      domain: config.domain)
    send = (subject, text) ->
      data =
        from: config.from,
        to: config.to,
        subject: subject
        text: text
      mailgun.messages().send data, (error, body) ->
        if error
          log "Error sending mail", error
        else
          log "Sent mail", subject, text
    { send }
  else
    {
      send: (subject, text) -> log "Pretending to send", subject, text
    }

module.exports = { initSite }
