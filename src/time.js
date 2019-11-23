const B=require("baconjs");
const moment=require("moment");
const now = () => moment();
const oneSecond = 1000;
const oneMinute = 60 * oneSecond;
const oneHour = 3600 * oneSecond;
const oneDay = 24 * oneHour;
const seconds = x => x * oneSecond;
const minutes = x => x * oneMinute;
const hours = x => x * oneHour;
const days = x => x * oneDay;
const currentWeekday = () => now().day();
const eachSecondE = B.interval(1000).map(now);
const eachMinuteE = eachSecondE.filter(t => t.seconds() === 0);
const eachHourE = eachMinuteE.filter(t => t.minutes() === 0);
const midnightE = eachHourE.filter(t => t.hours() === 0);
const hourOfDayP = eachHourE.toProperty(0).map(now).map(".hours").toProperty().skipDuplicates();
const dayOfWeekP = eachHourE.map(currentWeekday).toProperty(currentWeekday()).skipDuplicates();
const weekendP = dayOfWeekP.map(day => (day === 0) || (day === 6)).skipDuplicates();
const todayAt = function(hour, minute, second) {
  if (second == null) { second = 0; }
  if (typeof hour === "string") {
    const parse = s => parseInt(s) || 0;
    const [h, m, s] = Array.from(hour.split(":"));
    [hour, minute, second] = Array.from([parse(h), parse(m), parse(s)]);
  }
  return now().hour(hour).minute(minute).second(second);
};
const formatDuration = millis => moment.duration(millis, 'milliseconds').humanize();

module.exports = {
  now,
  eachSecondE, eachMinuteE, eachHourE, midnightE,
  hourOfDayP,
  oneDay, oneHour, oneMinute, oneSecond,
  days, hours, minutes, seconds,
  formatDuration,
  todayAt,
  dayOfWeekP, weekendP,
  sunday: 0, monday:1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6
};
