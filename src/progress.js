export function dateInZone(now = new Date(), zone = 'America/Chicago') {
  const parts = new Intl.DateTimeFormat('en-US', {timeZone: zone, year:'numeric', month:'2-digit', day:'2-digit'}).formatToParts(now);
  const get = type => parts.find(p => p.type === type).value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}
export function schedule(start, today) {
  if (!start) return {current: 0, overdueThrough: 0, finished: false};
  const elapsed = Math.round((Date.parse(today + 'T00:00:00Z') - Date.parse(start + 'T00:00:00Z')) / 86400000);
  return {current: Math.max(0, Math.min(365, elapsed + 1)), overdueThrough: Math.max(0, Math.min(365, elapsed)), finished: elapsed >= 365};
}
export function progress(days, timetable) {
  const completed = new Set(days);
  let behind = 0;
  for(let day=1; day<=timetable.overdueThrough; day++) if(!completed.has(day)) behind++;
  return {total: completed.size, behind, todayDone: timetable.current > 0 && completed.has(timetable.current)};
}
