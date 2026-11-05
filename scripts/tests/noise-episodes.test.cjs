const {test} = require('node:test');
const assert = require('node:assert/strict');
const {findEpisodes} = require('../noise-episodes.js');
const rows = values => values.map((v,i)=>[i*60,v,v+5,400]);
test('groups repeated bursts into the maximal 33-minute episode',()=>{
  const data=rows(Array.from({length:33},(_,i)=>i%5>=3?30:60));
  const [b]=findEpisodes(data,55);
  assert.deepEqual([b.minutes,b.active,b.pause,b.pauses],[33,21,12,6]);
  assert.equal(findEpisodes(data,55,0).length,7);
});
test('never bridges missing, duplicate or invalid minute data',()=>{
  const data=rows([60,30,60,30,60]);
  for (const invalid of [data.filter((_,i)=>i!==2),[...data,data[2]],data.map((r,i)=>i===2?[120,NaN,NaN,400]:r)]) {
    assert.equal(findEpisodes(invalid,55,10).length,2);
  }
});
test('trims edge pauses, splits long pauses, supports equality and unsorted input',()=>{
  assert.deepEqual(findEpisodes(rows([30,55,30,30,30,55,30]).reverse(),55).map(b=>[b.start,b.end]),[[60,120],[300,360]]);
  assert.equal(findEpisodes(rows([30,30]),55).length,0);
  assert.throws(()=>findEpisodes([],NaN));
});
