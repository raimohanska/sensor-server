config = (require "./config").mailgun
log = require "./log"

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
  module.exports = { send }
else
  module.exports =
    send: (subject, text) -> log "Pretending to send", subject, text
