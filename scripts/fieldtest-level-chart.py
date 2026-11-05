#!/usr/bin/env python3
"""Render private minute-level field-test data without saving a database copy."""

import argparse
import datetime as dt
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import tempfile
from zoneinfo import ZoneInfo

PACKAGE = 'dev.moinsen.noisenet_mobile.fieldtest'
BERLIN = ZoneInfo('Europe/Berlin')


def read_snapshot(serial):
    result = subprocess.run(
        ['adb', '-s', serial, 'exec-out', 'run-as', PACKAGE,
         'cat', 'app_flutter/noisenet.db'],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=20)
    connection = sqlite3.connect(':memory:')
    try:
        connection.deserialize(result.stdout)
        if connection.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
            raise ValueError('Database integrity check failed')
        return connection.execute(
            'SELECT timestamp, leq_db, lmax_db, samples_count '
            'FROM noise_measurements ORDER BY timestamp, id').fetchall()
    finally:
        connection.close()


def stable_rows(serial):
    # ADB cannot take an SQLite read lock. Compare two in-memory snapshots and
    # require all older rows to match; report uncertainty instead of silently
    # treating a changing or corrupt file as a transactionally consistent copy.
    for _ in range(3):
        try:
            first, second = read_snapshot(serial), read_snapshot(serial)
            if not first or not second:
                return second
            cutoff = min(first[-1][0], second[-1][0])
            if [r for r in first if r[0] < cutoff] == [r for r in second if r[0] < cutoff]:
                return [r for r in second if r[0] < cutoff]
        except (sqlite3.Error, ValueError):
            continue
    raise RuntimeError('No stable, integrity-checked database snapshots available')


def filtered(rows, start, end):
    # Include only completed clock minutes inside the intended test period.
    # A saved row does not prove the minute had uninterrupted PCM capture.
    first_minute = math.ceil(start.timestamp() / 60) * 60
    end_seconds = end.timestamp()
    valid = []
    seen = set()
    for stamp, level, peak, count in rows:
        if not first_minute <= stamp or stamp + 60 > end_seconds:
            continue
        if stamp in seen or stamp % 60:
            raise ValueError('Duplicate or non-minute timestamps detected')
        if not (isinstance(level, (int, float)) and math.isfinite(level)
                and isinstance(peak, (int, float)) and math.isfinite(peak)
                and isinstance(count, int) and count > 0):
            raise ValueError('Invalid measurement')
        seen.add(stamp)
        valid.append([stamp, round(level, 2), round(peak, 2), count])
    return valid


def load_hints(path, start, end):
    if path is None:
        return []
    with path.open(encoding='utf-8') as source:
        report = json.load(source)
    hints = []
    for item in report['segments']:
        observed, category = item['observed_end'], item['category']
        duration, confidence = item['duration_ms'], item['confidence_pct']
        if not (isinstance(observed, (int, float)) and math.isfinite(observed)
                and isinstance(category, str) and re.fullmatch(r'[a-z_]{1,80}', category)
                and isinstance(duration, int) and 0 < duration <= 86400000
                and isinstance(confidence, int) and 0 <= confidence <= 100):
            raise ValueError('Invalid source hint')
        if start.timestamp() <= observed <= end.timestamp():
            hints.append({'observed_end': observed, 'category': category,
                          'duration_ms': duration, 'confidence_pct': confidence})
    return hints


def make_html(rows, start, end, hints=None):
    data = json.dumps({'rows': rows, 'start': start.isoformat(),
                       'snapshot': end.isoformat(), 'hints': hints or []},
                      separators=(',', ':'))
    data = data.replace('<', '\\u003c')
    return PAGE.replace('__DATA__', data).replace('__EPISODE_LOGIC__', Path(__file__).with_name('noise-episodes.js').read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', help='Read the existing field-test app without changing it')
    parser.add_argument('--database', type=Path, help='Read a private offline SQLite backup instead of ADB')
    parser.add_argument('--start', required=True, help='ISO date/time with time zone')
    parser.add_argument('--end', help='Optional ISO date/time with time zone')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--source-hints', type=Path, help='Optional private, incomplete debug-log snapshot')
    args = parser.parse_args()
    start = dt.datetime.fromisoformat(args.start)
    end = dt.datetime.fromisoformat(args.end) if args.end else dt.datetime.now(dt.timezone.utc)
    if start.tzinfo is None or end.tzinfo is None or end <= start:
        parser.error('start and end must have time zones and end must follow start')
    end = min(end, dt.datetime.now(dt.timezone.utc))
    if bool(args.serial) == bool(args.database):
        parser.error('Choose exactly one of --serial or --database')
    if args.database:
        connection = sqlite3.connect(args.database.expanduser().absolute().as_uri() + '?mode=ro', uri=True)
        try:
            if connection.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                raise ValueError('Backup integrity check failed')
            saved = connection.execute('SELECT timestamp, leq_db, lmax_db, samples_count FROM noise_measurements ORDER BY timestamp, id').fetchall()
            # Keep the original conservative latest-minute exclusion.
            saved = [r for r in saved if r[0] < saved[-1][0]] if saved else []
        finally:
            connection.close()
    else:
        saved = stable_rows(args.serial)
    rows = filtered(saved, start, end)
    if not rows:
        raise SystemExit('No complete minutes were found for the specified interval')
    destination = args.output.expanduser().absolute()
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    hints = load_hints(args.source_hints.expanduser() if args.source_hints else None, start, end)
    document = make_html(rows, start, end, hints)
    fd, temp_path = tempfile.mkstemp(prefix='.noisenet-chart-', dir=destination.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as out:
            out.write(document)
        os.replace(temp_path, destination)
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)
    print(f'Private report: {destination}')
    print(f'{len(rows)} completed clock-minute records; last: {dt.datetime.fromtimestamp(rows[-1][0], BERLIN):%d.%m.%Y %H:%M %Z}')


PAGE = '''<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OpenNoiseNet – privater Feldtest</title>
<style>
:root{font-family:system-ui,-apple-system,sans-serif;color:#18302f;background:#f4f7f4}*{box-sizing:border-box}body{max-width:1120px;margin:auto;padding:24px}h1{font-size:clamp(1.65rem,4vw,2.5rem);margin:0 0 .4rem}.sub{color:#4f6662;line-height:1.5}.box{background:#fff;border:1px solid #dce6e0;border-radius:16px;padding:20px;margin:20px 0;box-shadow:0 5px 24px #18302f0b}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(175px,1fr));gap:12px}.card{background:#f1f7f3;border-radius:12px;padding:14px}.card strong{display:block;font-size:1.35rem;margin-top:5px}.legend{display:flex;flex-wrap:wrap;gap:20px;font-size:.9rem}.dot{display:inline-block;width:11px;height:11px;border-radius:50%;margin-right:6px}svg{width:100%;max-width:100%;height:auto;display:block;overflow:visible}svg text{font-family:system-ui;font-size:12px;fill:#536c65}.line{fill:none;stroke:#168460;stroke-width:2.1;stroke-linejoin:round}.peak{fill:none;stroke:#e3a051;stroke-width:1.2;opacity:.75}.grid{stroke:#e5ede8;stroke-width:1}.warn{background:#fff6e8;border-left:4px solid #db9b42;padding:14px;line-height:1.5}select,button{font:inherit;max-width:100%;padding:6px;border:1px solid #769487;border-radius:6px;background:#fff;color:#18302f}button{cursor:pointer;text-align:left}table{display:block;overflow-x:auto;width:100%;border-collapse:collapse;font-size:.92rem}td,th{padding:9px;text-align:left;border-bottom:1px solid #e7eee9}th{color:#4f6662}.small{font-size:.86rem;color:#566d67;line-height:1.5}@media(max-width:600px){body{padding:14px}.box{padding:14px}table{font-size:.78rem}td,th{padding:7px 3px}}
</style></head><body>
<p class="small">OPEN NOISENET · PRIVATER FELDTEST · PIXEL 10A</p><h1>Geräuschverlauf im Testzeitraum</h1><p class="sub" id="period"></p>
<div class="warn"><strong>Orientierung, keine Schallpegelmessung:</strong> Dieser Pixel-Test nutzt eine ältere, ungeeichte Pegelberechnung mit pegelabhängiger Korrektur. Sie ist keine normgerechte A-Bewertung und kann auch Abstände zwischen leisen und lauten Phasen verzerren. Niedrige Werte deuten auf relativ ruhigere Abschnitte, nicht auf Stille. Weder absolute Schalldruckwerte, dB(A), Geräuschquellen noch Rechtsgrenzwerte lassen sich daraus sicher ableiten.</div>
<div class="box"><div class="cards" id="cards"></div></div>
<div class="box"><h2>Zusammenhängende Episoden mit kurzen Pausen</h2><p>Wiederkehrende erhöhte Minuten gehören zu einer Episode, solange die gemessenen Pausen nicht länger als gewählt sind. Fehlende Messminuten trennen immer. Die gesamte Zeitspanne und die Minuten über der Linie werden getrennt gezählt. Eine solche Gruppe beweist weder dieselbe Ursache noch eine Belästigung.</p>
<label for="scope">Zeitraum ansehen:</label> <select id="scope"><option value="all">Gesamter Testzeitraum</option></select><br><br>
<label for="cutoff">Vergleichslinie: <strong id="cutoff-value"></strong></label> <input id="cutoff" type="range" step="1" aria-describedby="cutoff-help"><br>
<label for="pause">Kurze Pausen verbinden:</label> <select id="pause"><option value="0">Ohne Pausen</option><option value="1">Bis 1 Minute</option><option value="2">Bis 2 Minuten</option><option value="3">Bis 3 Minuten</option><option value="5" selected>Bis 5 Minuten</option><option value="10">Bis 10 Minuten</option></select>
<p class="small" id="cutoff-help">Der Startwert liegt 10 Punkte über dem Median. Linie und Pausentoleranz sind frei wählbare Analysehilfen. Sie verändern Anzahl und Länge der Episoden. Kürzere Geräusche bleiben im Minutenmittel möglicherweise verborgen. Stundenansichten schneiden Episoden an den Ansichtsgrenzen ab.</p><p id="blocks-summary"></p>
<div style="overflow-x:auto"><table><thead><tr><th>Zeitraum / Details</th><th>Gesamt</th><th>Über Linie</th><th>Pausen</th><th>Mittel / höchste Minute</th><th>Quellenhistorie</th></tr></thead><tbody id="blocks"></tbody></table></div>
<div id="episode-detail" aria-live="polite"></div></div>
<div class="box"><h2>Mögliche Geräuscharten: begrenzter Diagnoseausschnitt</h2><p class="small">Nur einzelne, noch im flüchtigen Diagnosepuffer vorhandene Modellhinweise. Die Liste ist nicht vollständig; fehlende Hinweise bedeuten keine Stille. Eine Kategorie ist eine unbestätigte Modellvermutung, keine nachgewiesene Ursache und keine Feststellung einer Belästigung. Die Protokollzeit kann gegenüber dem Ton zeitlich versetzt sein. Modellwerte sind keine geprüften Wahrscheinlichkeiten.</p><p id="hints-summary"></p><table><thead><tr><th>Ungefähr protokolliert</th><th>Modellvorschlag</th><th>Erkannte Dauer</th><th>Modellwert</th></tr></thead><tbody id="hints"></tbody></table></div>
<div class="box"><h2>Minuten im Verlauf</h2><p class="legend"><span><i class="dot" style="background:#168460"></i>Energetisches Mittel der geschätzten Pufferwerte pro Minute</span><span><i class="dot" style="background:#e3a051"></i>Höchster erfasster Pufferwert pro Minute</span></p><svg id="chart" viewBox="0 0 1000 340" role="img" aria-label="Zeitverlauf der gespeicherten Minutenwerte"></svg><p class="small">Lücken werden nicht verbunden. Die neueste gespeicherte Minute bleibt vorsorglich außen vor; angebrochene Randminuten des Testfensters sind ausgeschlossen. Ein Punkt entspricht einer gespeicherten Minute; kurze Einzelgeräusche können im Minutenmittel untergehen. Die orange Linie ist kein normgerechter Spitzenpegel. Zeiten: Europe/Berlin.</p></div>
<div class="box"><h2>Stunde für Stunde</h2><p class="small">Der mittlere Tabellenwert ist der Median der gespeicherten Minutenpegel, kein energiegewichteter Stunden-Leq. Angebrochene Stunden sind entsprechend kürzer.</p><table><thead><tr><th>Zeitraum</th><th>Minuten</th><th>Typisch</th><th>Höchste Minute</th></tr></thead><tbody id="hours"></tbody></table></div>
<p class="small">Diese Datei enthält private Messwerte und bleibt lokal. Sie enthält keine Tonaufnahmen. Das Diagramm belegt weder einen Ereignis-Upload noch die Genauigkeit des Geräts.</p>
<script>
__EPISODE_LOGIC__
const data=__DATA__,rows=data.rows;
const f=(t,opts)=>new Intl.DateTimeFormat('de-DE',{timeZone:'Europe/Berlin',...opts}).format(new Date(t*1000));
const time=t=>f(t,{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'});
const value=n=>n.toFixed(1).replace('.',',');
const sorted=rows.slice().sort((a,b)=>a[1]-b[1]), med=a=>{let s=a.slice().sort((x,y)=>x-y),n=s.length;return n%2?s[(n-1)/2]:(s[n/2-1]+s[n/2])/2};
const max=sorted[sorted.length-1], min=sorted[0];
const missing=Math.max(0,Math.round((rows[rows.length-1][0]-rows[0][0])/60)+1-rows.length);
document.getElementById('period').textContent='Testfenster: '+new Date(data.start).toLocaleString('de-DE',{timeZone:'Europe/Berlin'})+' bis '+new Date(data.snapshot).toLocaleString('de-DE',{timeZone:'Europe/Berlin'})+' Uhr · dargestellte Minuten: '+f(rows[0][0],{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'})+' bis '+f(rows[rows.length-1][0]+60,{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'})+' Uhr';
const cards=[['Gespeicherte Minuten',rows.length.toLocaleString('de-DE')],['Niedrigster Minutenwert',time(min[0])+' · '+value(min[1])],['Höchster Minutenwert',time(max[0])+' · '+value(max[1])],['Lücken zwischen Messungen',String(missing)]];
document.getElementById('cards').innerHTML=cards.map(([a,b])=>'<div class="card">'+a+'<strong>'+b+'</strong></div>').join('');
const cutoff=document.getElementById('cutoff'),pause=document.getElementById('pause'),scope=document.getElementById('scope');cutoff.min=Math.floor(min[1]);cutoff.max=Math.ceil(max[1]);cutoff.value=Math.min(Number(cutoff.max),Math.round(med(rows.map(r=>r[1]))+10));
const hourKey=r=>f(r[0],{day:'2-digit',month:'2-digit',hour:'2-digit'});
const scopes=new Map();for(const r of rows){const key=hourKey(r);if(!scopes.has(key))scopes.set(key,[]);scopes.get(key).push(r)}
for(const [key,rs] of scopes){const option=document.createElement('option');option.value=key;option.textContent=time(rs[0][0])+' – '+time(rs[rs.length-1][0]+60);scope.appendChild(option)}
function sourceHints(b){return data.hints.filter(h=>h.observed_end>b.start&&h.observed_end-h.duration_ms/1000<b.end)}
function hintLabel(h){return labels[h.category]||'Sonstiger Modellhinweis'}
function showEpisode(b){
 const host=document.getElementById('episode-detail');host.replaceChildren();
 const title=document.createElement('h3');title.textContent=time(b.start)+' – '+time(b.end);host.appendChild(title);
 const summary=document.createElement('p');summary.textContent=b.minutes+' Minuten insgesamt: '+b.active+' Minuten auf/über der Linie und '+b.pause+' Minuten in '+b.pauses+' kurzen Pausen.';host.appendChild(summary);
 const stripe=document.createElement('div');stripe.style.cssText='display:flex;gap:2px;height:32px';stripe.setAttribute('role','img');stripe.setAttribute('aria-label','Minutenstreifen: grün über der Linie, grau kurze Pause');
 for(const r of b.rows){const bar=document.createElement('span');bar.style.cssText='flex:1;background:'+(r[1]>=Number(cutoff.value)?'#168460':'#d8e1dc');bar.title=time(r[0])+' · '+value(r[1]);stripe.appendChild(bar)}host.appendChild(stripe);
 const legend=document.createElement('p');legend.className='small';legend.textContent='Jeder Streifen ist eine gespeicherte Minute. Grün: auf/über der Linie. Grau: gemessene kurze Pause unter der Linie, kein Nachweis von Stille.';host.appendChild(legend);
 const hints=sourceHints(b),note=document.createElement('p');note.textContent=hints.length?'Zeitgleiche, unvollständige Modellhinweise (keine bestätigte Ursache):':'Für diesen Zeitraum wurde keine Quellenhistorie gesichert. Aus dem Pegelverlauf lässt sich die Ursache nicht nachträglich bestimmen.';host.appendChild(note);
 for(const h of hints){const item=document.createElement('p');item.textContent='ca. '+time(Math.max(b.start,h.observed_end-h.duration_ms/1000))+' – '+time(Math.min(b.end,h.observed_end))+' · '+hintLabel(h)+' · Modellhinweis';host.appendChild(item)}
}
function updateBlocks(){
 const threshold=Number(cutoff.value),chosen=scope.value==='all'?rows:scopes.get(scope.value),blocks=findEpisodes(chosen,threshold,Number(pause.value));
 document.getElementById('cutoff-value').textContent=value(threshold);
 document.getElementById('blocks-summary').textContent=blocks.length?blocks.length+' Episoden, nach Gesamtdauer sortiert. Längste: '+blocks[0].minutes+' Minuten, davon '+blocks[0].active+' über der Linie und '+blocks[0].pause+' in kurzen Pausen.':'Keine Episode auf dieser Vergleichslinie.';
 const body=document.getElementById('blocks');body.replaceChildren();
 for(const b of blocks){const tr=document.createElement('tr'),first=document.createElement('td'),button=document.createElement('button');button.textContent=time(b.start)+' – '+time(b.end);button.addEventListener('click',()=>showEpisode(b));first.appendChild(button);tr.appendChild(first);
  for(const v of [b.minutes+' Min.',b.active+' Min.',b.pause+' Min. / '+b.pauses+' Pausen',value(b.average)+' / '+value(b.highest),sourceHints(b).length?'Zeitgleiche Modellhinweise · Details':'In diesem Zeitraum nicht gespeichert']){const td=document.createElement('td');td.textContent=v;tr.appendChild(td)}body.appendChild(tr)}
 if(blocks.length)showEpisode(blocks[0]);else document.getElementById('episode-detail').replaceChildren();
}
cutoff.addEventListener('input',updateBlocks);pause.addEventListener('change',updateBlocks);scope.addEventListener('change',updateBlocks);
const labels={loud_conversation:'Laute Unterhaltung',television_or_music:'Fernsehen oder Musik',party_or_music_with_people:'Party oder Musik mit Menschen',road_traffic:'Straßenverkehr',construction_other:'Baugeräusch',unknown_sound_source:'Unbekannt'};
updateBlocks();
const hints=data.hints.slice().sort((a,b)=>a.observed_end-b.observed_end);document.getElementById('hints-summary').textContent=hints.length?hints.length+' einzelne Hinweise aus einem unvollständigen Ausschnitt. Zeitliche Überschneidungen erscheinen in den Episodendetails; keine bestätigte Ursache.':'Keine Quellhinweise für diesen Ausschnitt verfügbar.';
document.getElementById('hints').innerHTML=hints.map(h=>'<tr><td>ca. '+time(h.observed_end)+'</td><td>'+(labels[h.category]||'Sonstiger Modellhinweis')+'</td><td>'+value(h.duration_ms/1000)+' Sek.</td><td>'+h.confidence_pct+' %</td></tr>').join('');
const svg=document.getElementById('chart'),ns='http://www.w3.org/2000/svg',W=1000,H=340,L=52,R=18,T=14,B=46;
function node(tag,attrs,text){let e=document.createElementNS(ns,tag);Object.entries(attrs).forEach(([k,v])=>e.setAttribute(k,v));if(text!==undefined)e.textContent=text;svg.appendChild(e);return e}
const x0=rows[0][0],x1=Math.max(rows[rows.length-1][0],x0+60),lo=Math.floor(Math.min(...rows.map(r=>r[1]))/10)*10,hi=Math.ceil(Math.max(...rows.map(r=>r[2]))/10)*10,spread=Math.max(10,hi-lo),x=t=>L+(t-x0)/(x1-x0)*(W-L-R),y=v=>T+(hi-v)/spread*(H-T-B);
for(let v=lo;v<=hi;v+=10){node('line',{x1:L,y1:y(v),x2:W-R,y2:y(v),class:'grid'});node('text',{x:L-8,y:y(v)+4,'text-anchor':'end'},String(v))}
for(let i=0;i<=6;i++){let t=x0+(x1-x0)*i/6;node('text',{x:x(t),y:H-14,'text-anchor':i===0?'start':i===6?'end':'middle'},f(t,{hour:'2-digit',minute:'2-digit'}))}
function draw(col,cls){let path='',last=null;for(const r of rows){path+=(last===null||r[0]-last>60?'M':'L')+x(r[0]).toFixed(1)+' '+y(r[col]).toFixed(1)+' ';last=r[0]}node('path',{d:path,class:cls})}draw(2,'peak');draw(1,'line');
const groups=new Map();for(const r of rows){let label=f(r[0],{day:'2-digit',month:'2-digit',hour:'2-digit'});if(!groups.has(label))groups.set(label,[]);groups.get(label).push(r)}
document.getElementById('hours').innerHTML=[...groups].map(([label,rs])=>'<tr><td>'+label+' Uhr</td><td>'+rs.length+'</td><td>'+value(med(rs.map(r=>r[1])))+'</td><td>'+value(Math.max(...rs.map(r=>r[1])))+'</td></tr>').join('');
</script></body></html>'''

if __name__ == '__main__':
    main()
