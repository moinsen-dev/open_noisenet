#!/usr/bin/env python3
"""Render the public AMI fixture evaluation as a standalone offline report.

Consumes test-natural-conversations.py output; never reads Pixel field data.
"""

import argparse
import html
import json
from pathlib import Path


def clock(ms):
    seconds = round(ms / 1000)
    return f"{seconds // 60}:{seconds % 60:02d}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    results = json.loads((args.root / "natural-conversation-results.json").read_text())
    upload = json.loads((args.root / "http-integration-result.json").read_text())
    concurrency = json.loads(
        (args.root / "postgres-concurrency-result.json").read_text()
    )
    cards = []
    for scene in results["scenes"]:
        phases = [p for p in scene["phases"] if p["family"] == "speech"]
        longest = max(phases, key=lambda p: p["end_ms"] - p["start_ms"])
        scale = 1000 / scene["duration_ms"]
        shapes = []
        for minute in range(0, 21, 5):
            x = 20 + minute * 50
            shapes.append(
                f'<path d="M{x} 12V88" stroke="#dae2de"/><text x="{x}" y="111" text-anchor="middle">{minute} min</text>'
            )
        for p in phases:
            title = html.escape(
                f"Sprachphase {clock(p['start_ms'])}–{clock(p['end_ms'])}; aktiv {clock(p['active_ms'])}, Pausen {clock(p['pause_ms'])}"
            )
            shapes.append(
                f'<rect class="parent" x="{20 + p["start_ms"] * scale:.3f}" y="24" width="{(p["end_ms"] - p["start_ms"]) * scale:.3f}" height="50" rx="4"><title>{title}</title></rect>'
            )
            for a in p["activity"]:
                shapes.append(
                    f'<rect x="{20 + a["start_ms"] * scale:.3f}" y="34" width="{(a["end_ms"] - a["start_ms"]) * scale:.3f}" height="30" fill="#18644c"><title>{html.escape(clock(a["start_ms"]) + "–" + clock(a["end_ms"]))} Sprachhinweis</title></rect>'
                )
        extra = (
            "Kurzer Anfangsabschnitt bleibt getrennt: zu wenig Aktivität vor der Pause."
            if len(phases) > 1
            else "Eine zusammenhängende Sprachphase über nahezu den gesamten Ausschnitt."
        )
        if any(p["family"] != "speech" for p in scene["phases"]):
            extra += " Zusätzlich 1,46 s ungeprüfter Musikhinweis; hier nur Sprache dargestellt."
        cards.append(
            f"""<article><div class="cardhead"><div><p class="eyebrow">NATÜRLICHE BESPRECHUNG · {html.escape(scene['id'])}</p><h2>{clock(scene['longest_phase_ms'])} Minuten am Stück</h2></div><span class="badge">{len(phases)} {"Sprachphase" if len(phases) == 1 else "Sprachphasen"}</span></div>
<svg viewBox="0 0 1040 125" role="img" aria-label="Zwanzig Minuten: zusammenhängende Sprachphasen mit aktiven Abschnitten und Pausen">{''.join(shapes)}</svg>
<div class="metrics"><span><b>{clock(longest['active_ms'])}</b> aktiv im größten Block</span><span><b>{clock(longest['pause_ms'])}</b> Pausen im größten Block</span><span><b>{scene['word_time_recall']:.1%}</b> der annotierten Wortzeit überdeckt</span></div><p class="note">{extra}</p></article>"""
        )
    checks = [
        (
            upload["natural_phase_count"] == 1,
            "Eine Serverphase",
            f"{clock(upload['span_ms'])} Minuten, {upload['last_revision']} Revisionen mit gleicher Kennung",
        ),
        (
            upload["offline_resume"] and upload["lost_ack_retried"],
            "Offline und verlorene Antwort",
            "Fortsetzung aus verschlüsselter App-Warteschlange bestätigt",
        ),
        (
            upload["restart_marked_interrupted"],
            "Neustart ehrlich getrennt",
            "Vorherige Phase als unterbrochen abgeschlossen",
        ),
        (
            upload["remote_erasure_confirmed"]
            and concurrency["delete_upload_race_cannot_resurrect"],
            "Löschung bestätigt",
            "Verspätete Uploads stellen gelöschte Inhalte nicht wieder her",
        ),
    ]
    evidence = "".join(
        f'<li><b>{"✓" if ok else "✕"} {title}</b><span>{detail}</span></li>'
        for ok, title, detail in checks
    )
    page = (
        """<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OpenNoiseNet · Natürliche Gesprächsphasen</title><link rel="icon" href="data:,">
<style>*{box-sizing:border-box}body{margin:0;background:#f2f5ef;color:#172b25;font:16px/1.55 system-ui,sans-serif}main{max-width:1100px;margin:auto;padding:42px 24px 55px}.eyebrow{font-size:12px;letter-spacing:.1em;color:#49675b;margin:0 0 10px}h1{font-size:clamp(32px,5vw,52px);line-height:1.12;max-width:850px;margin:0 0 20px;letter-spacing:-.035em}h2{font-size:25px;line-height:1.25;margin:0}.intro{max-width:860px;color:#3e554b;font-size:18px}.legend{display:flex;flex-wrap:wrap;gap:16px;margin:24px 0}.legend span{display:inline-flex;align-items:center;gap:7px}.swatch{width:20px;height:14px;background:#18644c;border-radius:3px}.swatch.phase{background:#d2e9d9;border:1px solid #44826b}.swatch.pause{background:#d2e9d9}.controls{margin:20px 0}input{accent-color:#18644c;width:18px;height:18px;vertical-align:middle}article{padding:24px;background:#fff;border:1px solid #dce5db;border-radius:18px;margin:18px 0}.cardhead{display:flex;justify-content:space-between;gap:15px;align-items:center}.badge{background:#edf5ee;border-radius:30px;padding:7px 12px;white-space:nowrap;font-size:13px}svg{display:block;width:100%;margin:22px 0 5px;overflow:visible}svg text{font:13px system-ui;fill:#53695e}.parent{fill:#d2e9d9;stroke:#44826b}.raw .parent{visibility:hidden}.metrics{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;font-size:13px;color:#52675d}.metrics b{display:block;font-size:23px;color:#172b25}.note{font-size:14px;color:#5c6656;margin:18px 0 0;padding-top:14px;border-top:1px solid #e5ebe4}.proof{background:#172f28;color:#f4faf5;border-radius:18px;padding:26px;margin:30px 0}.proof ul{list-style:none;padding:0;display:grid;grid-template-columns:1fr 1fr;gap:24px}.proof span{display:block;color:#c2d8ca;font-size:14px;margin-top:5px}.limits{max-width:950px;font-size:15px}.limits li{margin:9px 0}a{color:inherit}footer{border-top:1px solid #cdd8ce;margin-top:35px;padding-top:18px;color:#5b6d60;font-size:13px}@media(max-width:650px){main{padding:25px 14px}article{padding:18px 14px}.cardhead{display:block}.badge{display:inline-block;margin-top:12px}.metrics{grid-template-columns:1fr;gap:12px}.metrics b{display:inline;font-size:18px;margin-right:8px}.proof ul{grid-template-columns:1fr}svg text{font-size:32px}}</style>
<main><p class="eyebrow">OPENNOISENET · LOKALE PRÜFUNG · 5. NOVEMBER 2026</p><h1>Ein Gespräch besteht aus mehr als einzelnen Sprachfetzen.</h1><p class="intro">Die neue Zeitlogik verbindet wiederkehrende Sprachhinweise über kurze Pausen. Drei reale Mikrofonspuren zeigen große Blöcke von rund 19 bis 20 Minuten. Der neue Upload erhält diese Blöcke als fortlaufend aktualisierte Phasen.</p>
<div class="legend"><span><i class="swatch phase"></i>Zusammenhängende Phase</span><span><i class="swatch"></i>Aktiver Sprachhinweis</span><span><i class="swatch pause"></i>Überbrückte Pause</span></div>
<label class="controls"><input id="raw" type="checkbox"> Nur einzelne Sprachhinweise zeigen – Phasenrahmen ausblenden</label>
"""
        + "".join(cards)
        + """<section class="proof"><h2>Von der App-Warteschlange bis PostgreSQL geprüft</h2><p>Mit den Modellhinweisen der dritten Szene, über echte lokale HTTP-Anfragen und eine getrennte Testdatenbank.</p><ul>"""
        + evidence
        + """</ul></section>
<section class="limits"><h2>Was diese Prüfung belegt – und was offen bleibt</h2><ul>
<li>Zwei echte englischsprachige AMI-Besprechungen mit jeweils vier annotierten Sprechern. EN2002b wird über zwei Mikrofonspuren desselben Treffens betrachtet; es sind keine drei unabhängigen Gespräche.</li>
<li>Jeweils Originalminute 1–21; die Grafik beginnt bei Ausschnittsekunde 0. YAMNet verarbeitet alle vollständigen 975-ms-Fenster bei 480-ms-Schrittweite. Die letzten 465 ms haben kein vollständiges Fenster. Keine nachträgliche Abstimmung der Zeitregeln auf diese Aufnahmen.</li>
<li>Die kurze Anfangsphase bei EN2002b bleibt aufgrund geringer vorausgehender Aktivität und einer Pause getrennt. Das ist eine bekannte Grenze der aktuellen Regel, kein erfolgreich verbundener Gesamtblock.</li>
<li>„Wortzeit überdeckt“ vergleicht Modellaktivität mit manuellen Wortzeitmarken. Es ist keine allgemeine Erkennungsgenauigkeit. Pausen, nichtsprachliche Laute und Modellfenster beeinflussen die Überlappung.</li>
<li>Die Kategorien sind Modellhinweise. Die Logik erkennt weder Gesprächsinhalte noch Personen, gemeinsame Verursacher oder tatsächliche Belästigung. Lautstärke wird hier nicht bewertet.</li>
<li>Upload nur nach eigener Aktivierung, lokal verschlüsselte Warteschlange, auf dem Server privat und für dessen Betreiber lesbar. Keine Audiodateien, Transkripte, Koordinaten oder Embeddings im Upload. Löschen entfernt Inhalte; minimale Löschmarken bleiben gegen verspätete Wiederholungen.</li>
<li>Lokaler Integrationsnachweis, keine neue physische Geräte- oder HTTPS-Prüfung. Der laufende Pixel-Dauertest wurde weder verändert noch durch abgespielte Testgeräusche beeinflusst.</li></ul></section>
<footer>Quelle: <a href="https://groups.inf.ed.ac.uk/ami/corpus/">AMI Meeting Corpus</a> · AMI Consortium / University of Edinburgh · <a href="https://creativecommons.org/licenses/by/4.0/">CC BY 4.0</a>. Abgeleitete Zeitintervalle und Auswertung von OpenNoiseNet. Dieser Bericht enthält keine privaten Pixel-Messwerte, Audiodateien oder Transkripte. Keine externen Skripte oder Schriftarten.</footer></main>
<script>document.getElementById('raw').addEventListener('change',e=>document.body.classList.toggle('raw',e.target.checked));</script></html>"""
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(page, encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
