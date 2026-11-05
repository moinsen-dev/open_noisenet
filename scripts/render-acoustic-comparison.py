#!/usr/bin/env python3
"""Render already completed local benchmark results; no external requests."""
import argparse
import html
import json
from pathlib import Path


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    a = ap.parse_args()
    comparison = json.loads((a.root/'comparison.json').read_text())
    replay = json.loads((a.root/'scene-replay.json').read_text())
    audio = [json.loads((a.root/f'{name}-audio-scene.json').read_text()) for name in ['yamnet','gemma']]
    matched = [json.loads((a.root/f'{name}-audio-scene-matched.json').read_text()) for name in ['yamnet','gemma']]
    table = ''
    for key, name in [('yamnet','YAMNet – gleicher Vergleichsklassifikator'),('gemma','EmbeddingGemma 2 – gleicher Vergleichsklassifikator')]:
        m = comparison['models'][key];r=m['runtime']
        table += f'<tr><td>{name}</td><td>{m["correct"]}/{m["total"]}</td><td>{r["median_seconds_per_4_815s_clip"]*1000:.1f} ms</td><td>{r["process_peak_rss_bytes"]/1024**3:.2f} GiB</td></tr>'
    def lane(phases, duration):
        svg = ['<svg viewBox="0 0 900 70" role="img" aria-label="Sprachphasen mit aktiven Abschnitten"><rect x="0" y="14" width="900" height="32" rx="5" fill="#edf0f1"/>']
        for p in phases:
            if p['family'] != 'speech':continue
            x=p['start_ms']/duration*900;w=(p['end_ms']-p['start_ms'])/duration*900
            svg.append(f'<rect x="{x:.2f}" y="9" width="{w:.2f}" height="42" rx="4" fill="#d4e9e4" stroke="#167761"/>')
            for part in p['activity']:
                x=part['start_ms']/duration*900;w=(part['end_ms']-part['start_ms'])/duration*900
                svg.append(f'<rect x="{x:.2f}" y="17" width="{w:.2f}" height="26" fill="#167761"/>')
        svg.append(f'<text x="0" y="67">0 min</text><text x="900" y="67" text-anchor="end">{duration/60000:g} min</text></svg>')
        return ''.join(svg)
    def scene_box(scene,duration):
        ps=[p for p in scene['phases'] if p['family']=='speech']
        largest=max((p['end_ms']-p['start_ms'] for p in ps),default=0)
        return f'<article><h3>{html.escape(scene["id"])}</h3><p>{len(ps)} Sprachphasen · längste {largest/60000:.2f} Minuten</p>{lane(ps,duration)}<details><summary>Zeitgrenzen ansehen</summary>'+''.join(f'<p>{p["start_ms"]/1000:.2f}–{p["end_ms"]/1000:.2f} s · aktiv {p["active_ms"]/1000:.2f} s · Zwischenräume {p["pause_ms"]/1000:.2f} s</p>' for p in ps)+'</details></article>'
    replay_html=''.join(scene_box(s,1980000 if '33m' in s['id'] else 600000 if 'sparse' in s['id'] else 900000) for s in replay['scenes'])
    audio_html=''.join(scene_box(s,300000) for run in matched for s in run['scenes'])
    exploratory_html=''.join(scene_box(s,300000) for run in audio for s in run['scenes'])
    errors = ''
    for run, name in zip(matched, ['YAMNet', 'EmbeddingGemma 2']):
        phases = run['scenes'][0]['phases']
        unexpected = [p for p in phases if p['family'] not in ['speech', 'impact']]
        mistakes = ', '.join(f'{p["family"]}: {p["active_ms"]/1000:.3f} s' for p in unexpected) or 'keine'
        errors += f'<tr><td>{name}</td><td>{mistakes}</td><td>{run["inference_seconds"]:.3f} s</td></tr>'
    body=f'''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="icon" href="data:,"><title>OpenNoiseNet – Geräuschphasen im Test</title>
<style>body{{font:16px/1.5 system-ui,sans-serif;max-width:1050px;margin:auto;padding:24px;background:#f3f6f5;color:#173a33}}h1{{font-size:clamp(1.7rem,5vw,2.8rem);line-height:1.1}}h2{{margin-top:2em}}h3{{overflow-wrap:anywhere}}article,.box{{background:white;border:1px solid #d5e0db;border-radius:16px;padding:20px;margin:16px 0}}svg{{width:100%;height:auto}}svg text{{font:14px system-ui;fill:#4a605a}}.tag{{color:#59695e}}.lead{{font-size:1.2rem}}table{{width:100%;border-collapse:collapse}}td,th{{padding:12px;border-bottom:1px solid #ddd;text-align:left}}.scroll{{overflow:auto}}summary{{cursor:pointer}}@media(max-width:500px){{body{{padding:14px}}article{{padding:12px}}}}</style>
<p class="tag">5. November 2026 · Kontrollierte Testdaten · keine Pixel-Messung</p>
<h1>Aus kurzen Hinweisen werden Geräuschphasen</h1>
<p class="lead">Die neue Zeitlogik verbindet Sprechpausen, trennt längere Unterbrechungen und macht Analyse-Lücken sichtbar.</p>
<div class="box"><strong>Was hier geprüft wurde</strong><p>Sieben Intervalleigenschaften, ein 33-Minuten-Ablauf mit wiedergegebenen Modellentscheidungen und eine echte fünfminütige PCM-Testspur mit gleitender Modellinferenz. Die Tests verwenden öffentliche Umweltgeräusche und künstlich erzeugte Sprachbeispiele; keine privaten Aufnahmen.</p></div>
<h2>Modellvergleich: 12 zurückgehaltene Beispiele</h2><div class="box scroll"><table><thead><tr><th>Verfahren</th><th>Richtig</th><th>Median je 4,815 s Audio</th><th>Spitze Prozess-RAM</th></tr></thead><tbody>{table}</tbody></table></div>
<p>Je sechs Klassen, zwei Entwicklungs- und zwei Prüfdateien pro Klasse, getrennte Quellaufnahmen. Gleicher Nächster-Schwerpunkt-Klassifikator: YAMNet-Klassenscores beziehungsweise Gemma-Audiovektoren. Die bisherige YAMNet-App-Zuordnung trifft separat {replay['yamnet_existing_head_family_correct']}/{replay['heldout_total']} Quellenfamilien. Das ist ein kleines Diagnoseexperiment, keine allgemeine Genauigkeit.</p>
<p>Laufzeiten: CPU dieses Macs, zwei Threads. RAM ist der gesamte jeweilige Python-Prozess einschließlich Laufzeitbibliotheken. Keine Pixel-, Akku- oder Temperaturmessung. Sprache ist hier synthetischer Monolog; Unterhaltung, TV und Erkennung durch Wände bleiben ungeprüft.</p>
<h2>Fünf Minuten Audio – tatsächlich inferiert</h2><p>Sprachaktivität liegt geplant bei 0–80 und 210–290 Sekunden, jeweils mit kurzen Pausen. Türklopfen bei 45 und 235 Sekunden. Die Variante „gap“ lässt Analysefenster von 250–255 Sekunden weg. Alle Modelle bekommen dieselben 975-ms-Fenster alle 480 ms; ausschließlich exakt erzeugte digitale Stille wird gemeinsam übersprungen.</p>
<p>Für diesen Vergleich wurden die Klassenmittel ausschließlich aus den Entwicklungsdateien mit denselben 975-ms-Fenstern gebildet. Keine Anpassung an die Prüfdateien. Die getrennt ausgewiesene bisherige App-Zuordnung verwendet weiterhin ihre vorhandenen YAMNet-Regeln.</p>
<div class="box"><strong>Beide finden die zwei Sprachphasen. Beide Vergleichsklassifikatoren machen aber Quellenfehler.</strong><div class="scroll"><table><thead><tr><th>Modell</th><th>Zusätzliche, falsche Quellenhinweise</th><th>Reine Inferenz, 268 Fenster</th></tr></thead><tbody>{errors}</tbody></table></div><p>In dieser Spur gibt es weder Tiere noch Verkehr. Die bisherige YAMNet-App-Zuordnung erzeugt hier keine solche zusätzliche Familie. Das belegt noch keine allgemeine Zuverlässigkeit. Der einfache Vergleichsklassifikator muss stets eine der sechs Klassen wählen; er besitzt keine geprüfte Enthaltungsschwelle. Auch die zeitliche Erkennung der Klopfgeräusche ist unvollständig.</p></div>
<p>Grün: als Sprache erkannte Aktivität. Heller Rahmen: zusammengefasste Phase. Grau: außerhalb dieser Phase; kein allgemeiner Nachweis von Ruhe.</p>{audio_html}
<details><summary>Erster Versuch mit ungleichen Kontextlängen: negativer Befund bleibt sichtbar</summary><p>Klassenmittel aus 4,815 Sekunden, Anwendung auf 975 ms: Gemma erzeugte 59,805 Sekunden falsche Verkehrsaktivität; YAMNet 1,455 Sekunden. Der anschließende Vergleich mit angepasster Fensterlänge reduziert diesen Gemma-Fehler auf 1,935 Sekunden, beseitigt ihn aber nicht. Diese nachträgliche Protokollkorrektur ist explorativ; neue unabhängige Szenen fehlen.</p>{exploratory_html}</details>
<h2>33 Minuten und Gegenbeispiele – Wiedergabe von Modellentscheidungen</h2><p>Hier werden Ergebnisse kurzer Prüfdateien nach einem bekannten Zeitplan wiederholt. Es handelt sich ausdrücklich nicht um 33 Minuten durchgehend inferiertes Audio. Der gleiche Dart-Kern wird in App, Export und diesem Prüfwerkzeug genutzt.</p>{replay_html}
<div class="box"><strong>Entscheidung für diesen Stand: YAMNet bleibt in der App.</strong><p>Die neue Zeitlogik löst die getestete Zersplitterung bereits mit YAMNet. Gemma zeigt Potenzial bei Einzelclips, aber keinen klaren Vorteil in dieser Zeitszene und deutlich höheren Rechenaufwand. Echte Gespräche, Medienwiedergabe und wechselnde Räume benötigen weitere unabhängige Referenzen.</p><p>Das laufende Pixel-Experiment wurde nicht verändert. Gemma ist nur lokal im separaten Vergleich ausgeführt worden, nicht in die Sensor-App übernommen. Neue Quellenphasen gelten nur für künftig mit expliziter Analyseabdeckung erfasste Historie; fehlende alte Abdeckung wird nicht erfunden.</p></div></html>'''
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(body)
    a.output.chmod(0o600)
    print(a.output)


if __name__ == '__main__':
    main()
