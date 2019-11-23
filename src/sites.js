const log = require("./log");

const sites = {};

const registerSite = function(siteId, site) {
  log("register site", siteId);
  return sites[siteId] = site;
};

const findSiteByEvent = function(event) {
  const siteId = event.siteId || "default";
  const site = sites[siteId];
  if ((site == null)) {
    log("Unknown site " + siteId + " in ", JSON.stringify(event));
    return null;
  } else if (event.siteKey !== site.config.siteKey) {
    log("Site key mismatch for site " + siteId + " in ", JSON.stringify(event));
    return null;
  } else {
    return site;
  }
};

module.exports = { findSiteByEvent, registerSite, sites };
