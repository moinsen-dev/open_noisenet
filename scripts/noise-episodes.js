// Shared by the private offline report and executable regression tests.
// Rows: timestamp seconds, estimated minute level, maximum, sample count.
function findEpisodes(measurements, threshold, maxPauseMinutes = 2) {
  if (!Number.isFinite(threshold) || !Number.isInteger(maxPauseMinutes) || maxPauseMinutes < 0) {
    throw new Error('Invalid episode parameters');
  }
  const counts = new Map();
  for (const row of measurements) counts.set(row[0], (counts.get(row[0]) || 0) + 1);
  const sorted = measurements.filter(r => counts.get(r[0]) === 1).slice().sort((a,b) => a[0]-b[0]);
  let blocks = [], current = [], pending = [], previous = null;
  function finish() {
    if (current.length) {
      const active = current.filter(r => r[1] >= threshold).length;
      let pauses = 0, inPause = false;
      for (const r of current) {
        if (r[1] < threshold) { if (!inPause) pauses++; inPause = true; }
        else inPause = false;
      }
      blocks.push({rows:current,start:current[0][0],end:current[current.length-1][0]+60,
        minutes:current.length,active,pause:current.length-active,pauses,
        highest:Math.max(...current.map(r=>r[1])),
        average:10*Math.log10(current.reduce((s,r)=>s+10**(r[1]/10),0)/current.length)});
    }
    current = []; pending = [];
  }
  for (const row of sorted) {
    if (previous !== null && row[0] !== previous+60) finish();
    previous = row[0];
    if (!Number.isFinite(row[1]) || row[0]%60 || !(row[3]>0)) {finish();continue;}
    if (row[1] >= threshold) {current.push(...pending,row);pending=[];}
    else if (current.length) {pending.push(row);if(pending.length>maxPauseMinutes)finish();}
  }
  finish();
  return blocks.sort((a,b)=>b.minutes-a.minutes||a.start-b.start);
}
if (typeof module !== 'undefined') module.exports = {findEpisodes};
