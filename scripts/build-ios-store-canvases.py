#!/usr/bin/env python3
"""Create offline iPhone screenshot compositions from real simulator captures."""
import base64
import html
from pathlib import Path

root = Path(__file__).resolve().parents[1] / 'docs/mobile/store-assets/2026-11-07'
out = root / 'app-store/de-DE'
out.mkdir(parents=True, exist_ok=True)
items = [
    ('01-phases', 'Wann war<br>es laut?', 'Geräuschphasen im Überblick.'),
    ('02-duration', 'Wie lange<br>dauerte es?', 'Zeiträume und kurze Pausen sehen.'),
    ('03-sources', 'Was könnte die<br>Quelle sein?', 'Mögliche Quellen als Modellhinweise.'),
    ('04-diary', 'Halte fest,<br>was dich stört.', 'Deine Beobachtung. Dein Lärmtagebuch.'),
    ('05-export', 'Dein Tagebuch.<br>Zum Weitergeben.', 'Als CSV exportieren. Speicherort selbst wählen.'),
]
for number, (name, title, caption) in enumerate(items, 1):
    raw = (root / 'raw/ios' / (name + '.png')).read_bytes()
    assert raw.startswith(b'\x89PNG\r\n\x1a\n')
    image = base64.b64encode(raw).decode('ascii')
    page = f'''<!doctype html><html lang="de"><meta charset="utf-8"><title>{html.escape(name)}</title>
<style>*{{box-sizing:border-box}}html,body{{margin:0;width:1320px;height:2868px;overflow:hidden}}body{{background:linear-gradient(150deg,#123d43,#071f27 80%);font-family:Arial,sans-serif;color:#f6f3e9}}.brand{{position:absolute;top:42px;left:90px;font-size:35px;font-weight:700}}.brand b{{color:#ffb075}}.number{{position:absolute;right:90px;top:44px;color:#a3c4c5;font-size:32px}}h1{{position:absolute;top:110px;left:90px;margin:0;font-size:98px;line-height:1.04;letter-spacing:-2px;color:#ffb075}}p{{position:absolute;top:328px;left:90px;margin:0;font-size:38px}}.screen{{position:absolute;top:420px;left:165px;width:990px;height:2151px;border-radius:32px;overflow:hidden;box-shadow:0 20px 55px #0007,0 0 0 6px #73979855}}img{{display:block;width:100%;height:100%}}footer{{position:absolute;bottom:100px;left:165px;right:165px;display:flex;justify-content:space-between;color:#c5d8d5;font-size:28px}}</style>
<div class="brand">Open<b>Noise</b>Net</div><div class="number">0{number} / 05</div><h1>{title}</h1><p>{html.escape(caption)}</p><div class="screen"><img src="data:image/png;base64,{image}" alt="Echte iOS-Simulatoransicht mit synthetischen Beispieldaten"></div><footer><span>Beispieldaten</span><span>iOS · Simulator</span></footer></html>'''
    (out / (name + '.html')).write_text(page)
print('Prepared five iOS layouts.')
