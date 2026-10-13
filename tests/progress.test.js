import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {schedule, progress, dateInZone} from '../src/progress.js';
const plan=JSON.parse(readFileSync(new URL('../src/plan.json',import.meta.url)));
test('attached plan has 365 unique sequential readings and wrapped passages',()=>{
  assert.deepEqual(plan.map(p=>p.day),Array.from({length:365},(_,i)=>i+1));
  const expected={1:'Genesis 1-3',4:'Job 1-5',131:'2 Samuel 10; 1 Chronicles 19; Psalm 20',143:'2 Samuel 24; 1 Chronicles 21-22; Psalm 30',200:'2 Kings 18; 2 Chronicles 29-31; Psalm 48',274:'Luke 1; John 1',322:'Acts 7-8',365:'Revelation 19-22'};
  for(const [day,reading] of Object.entries(expected))assert.equal(plan[Number(day)-1].reading,reading);
  assert.ok(plan.every(p=>p.reading && !p.reading.includes('  ')));
});
test('undecided and future starts create no overdue days',()=>{
  assert.equal(schedule(null,'2026-10-12').overdueThrough,0);
  assert.equal(schedule('2026-10-15','2026-10-12').current,0);
});
test('today becomes overdue tomorrow, and late joiners inherit earlier days',()=>{
  assert.deepEqual(schedule('2026-10-12','2026-10-12'),{current:1,overdueThrough:0,finished:false});
  const t=schedule('2026-10-12','2026-10-15');
  assert.equal(progress([],t).behind,3);
  assert.equal(progress([1,3,4],t).behind,1);
  assert.equal(progress([1,3,4],t).todayDone,true);
});
test('calendar calculations survive DST and year boundaries',()=>{
  assert.equal(schedule('2026-10-31','2026-11-02').current,3);
  assert.equal(schedule('2026-12-31','2027-01-01').current,2);
  assert.equal(dateInZone(new Date('2026-10-13T02:00:00Z'),'America/Chicago'),'2026-10-12');
});
test('day 365 becomes overdue after the plan ends; all unread days remain flagged',()=>{
  assert.equal(schedule('2026-01-01','2026-12-31').overdueThrough,364);
  const t=schedule('2026-01-01','2027-01-02');
  assert.deepEqual(t,{current:365,overdueThrough:365,finished:true});
  assert.equal(progress([365],t).behind,364);
  assert.equal(progress(Array.from({length:365},(_,i)=>i+1),t).behind,0);
});
