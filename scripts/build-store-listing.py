#!/usr/bin/env python3
"""Typeset unchanged device screenshots in a reproducible store layout.

Creates HTML canvases, metadata and an offline listing preview. Render each
canvas at 1080x1920 in a browser to produce the corresponding JPEG. No screen
pixels, labels or measurements are fabricated or retouched by this script.
"""
import base64
import hashlib
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'docs/mobile/store-assets/2026-11-07'
OUTPUT = ASSETS / 'google-play/de-DE'
STORY = [
    ('01-phases', 'Wann war<br>es laut?', 'Geräuschphasen im Überblick.'),
    ('02-duration', 'Wie lange<br>dauerte es?', 'Zusammenhänge sehen. Pausen erkennen.'),
    ('03-sources', 'Was könnte die<br>Quelle sein?', 'Mögliche Quellen mit Zeit und Dauer.'),
    ('04-diary', 'Halte fest,<br>was dich stört.', 'Deine Beobachtung. Dein Lärmtagebuch.'),
    ('05-export', 'Dein Tagebuch.<br>Zum Weitergeben.', 'Als CSV exportieren. Speicherort selbst wählen.'),
]


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source = (ROOT / 'docs/mobile/aso-first-pass-2026-11-07.md').read_text()
    block = source.split('**Langbeschreibung**\n', 1)[1].split('\nDer Titel', 1)[0]
    description = '\n'.join(line.removeprefix('> ').removeprefix('>').replace('**', '')
                            for line in block.strip().splitlines())
    metadata = {
        'language': 'de-DE', 'title': 'OpenNoiseNet: Lärmtagebuch',
        'short_description': 'Lärmphasen erkennen, mögliche Quellen sehen und Beobachtungen privat festhalten',
        'full_description': description,
        'status': 'Prepared draft; not submitted or published',
    }
    assert len(metadata['title']) <= 30
    assert len(metadata['short_description']) <= 80
    assert len(description) <= 4000
    (OUTPUT / 'metadata.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
    (OUTPUT / 'description.txt').write_text(description + '\n')
    manifest = []
    for i, (name, headline, subline) in enumerate(STORY, 1):
        raw = ASSETS / 'raw/android' / f'{name}.png'
        payload = raw.read_bytes()
        assert payload[:8] == b'\x89PNG\r\n\x1a\n'
        image = 'data:image/png;base64,' + base64.b64encode(payload).decode()
        page = f'''<!doctype html>
<html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>{html.escape(headline.replace('<br>', ' '))} – OpenNoiseNet</title>
<style>
* {{ box-sizing:border-box }}
html,body {{ margin:0; width:1080px; height:1920px; overflow:hidden }}
body {{ background:#092d33; color:#f6f3e9; font-family:Arial,sans-serif }}
.canvas {{ position:relative; width:1080px; height:1920px; background:linear-gradient(150deg,#123d43,#071f27 80%) }}
.brand {{ position:absolute; top:33px; left:72px; font-size:27px; font-weight:700; letter-spacing:1px }}
.brand b {{ color:#ffb075 }}
.number {{ position:absolute; right:72px; top:36px; color:#a3c4c5; font-size:25px }}
h1 {{ position:absolute; top:86px; left:72px; margin:0; font-size:78px; line-height:1.04; letter-spacing:-2px; font-weight:750; color:#ffb075 }}
.subline {{ position:absolute; top:267px; left:72px; margin:0; font-size:30px; line-height:1.25; color:#e1ece9 }}
.screen {{ position:absolute; left:108px; top:320px; width:864px; height:1536px; border-radius:28px; box-shadow:0 18px 50px #0007,0 0 0 6px #73979855; overflow:hidden; background:#111 }}
.screen img {{ display:block; width:100%; height:100%; object-fit:contain }}
.caption {{ position:absolute; bottom:20px; left:108px; right:108px; display:flex; justify-content:space-between; font-size:22px; letter-spacing:.2px; color:#c5d8d5 }}
</style>
<main class="canvas">
<div class="brand">Open<b>Noise</b>Net</div><div class="number">0{i} / 05</div>
<h1>{headline}</h1><p class="subline">{html.escape(subline)}</p>
<div class="screen"><img src="{image}" alt="Unveränderte Android-App-Ansicht mit synthetischen Beispieldaten"></div>
<div class="caption"><span>Beispieldaten</span><span>Android · 0.1.0</span></div>
</main></html>'''
        (OUTPUT / f'{name}.html').write_text(page)
        manifest.append({'file': f'{name}.jpg', 'raw': f'../../raw/android/{name}.png',
                         'raw_sha256': hashlib.sha256(payload).hexdigest(),
                         'headline': headline.replace('<br>', ' '), 'subline': subline,
                         'width': 1080, 'height': 1920})
    (OUTPUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    gallery = ''.join(f'<a href="{m["file"]}"><img src="{m["file"]}" alt="{html.escape(m["headline"])}"></a>' for m in manifest)
    paragraphs = ''.join(f'<p>{html.escape(p).replace(chr(10), "<br>")}</p>' for p in description.split('\n\n'))
    preview = f'''<!doctype html><html lang="de"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OpenNoiseNet – Vorschau des Store-Entwurfs</title>
<style>body{{margin:0;background:#092d33;color:#e7eeee;font:17px/1.6 Arial,sans-serif}}main{{max-width:1280px;padding:40px 24px;margin:auto}}.status{{color:#ffb075}}h1{{font-size:clamp(28px,4vw,46px);line-height:1.1}}.gallery{{display:flex;gap:16px;overflow:auto;padding:20px 0}}.gallery img{{width:228px;border-radius:10px;display:block}}.text{{max-width:760px}}a{{color:#a5dbe3}}small{{color:#b7cecc}}</style>
<main><p class="status">VORBEREITETER STORE-ENTWURF · DEUTSCH</p><h1>{metadata['title']}</h1>
<p>Moinsen Development · Kostenlos</p><p>{metadata['short_description']}</p>
<div class="gallery">{gallery}</div><small>Originalansichten des Android-Release 0.1.0 (6), synthetische Beispieldaten. Bilder zum Vergrößern anklicken.</small>
<div class="text">{paragraphs}</div><p><a href="metadata.json">Metadaten</a> · <a href="manifest.json">Bildfolge und Herkunft</a></p>
<p class="status">Dieser Entwurf ist keine veröffentlichte Google-Play-Seite.</p></main></html>'''
    (OUTPUT / 'preview.html').write_text(preview)
    print(f'Prepared {len(STORY)} canvases and metadata in {OUTPUT}')
    print('Text lengths:', len(metadata['title']), len(metadata['short_description']), len(description))


if __name__ == '__main__':
    main()
