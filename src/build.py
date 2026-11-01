"""Régénère les pages du palais à partir du gabarit et des données.

Usage : python3 src/data.py && python3 src/build.py
- index.html          : page autonome (GitHub Pages, ouverture locale)
- artifact.html       : contenu publié comme artifact claude.ai (sans squelette)
"""
import json, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
tpl = (ROOT / "src/template.html").read_text(encoding="utf-8")
els = json.loads((ROOT / "src/elements.json").read_text(encoding="utf-8"))
body = tpl.replace("__DATA__", json.dumps(els, ensure_ascii=False))
(ROOT / "artifact.html").write_text(body, encoding="utf-8")
head = ('<!doctype html><html lang="fr"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
        '<link rel="apple-touch-icon" sizes="180x180" href="icons/icon-180.png">'
        '<link rel="icon" type="image/png" sizes="192x192" href="icons/icon-192.png">'
        '<link rel="manifest" href="manifest.webmanifest">'
        '<meta name="apple-mobile-web-app-title" content="PM Chimie">'
        '<meta name="apple-mobile-web-app-capable" content="yes">'
        '<meta name="mobile-web-app-capable" content="yes">'
        '<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">'
        '<meta name="theme-color" content="#1b1e22">'
        '<style>:root{color-scheme:light;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}'
        'body{margin:0}</style></head><body>')
(ROOT / "index.html").write_text(head + body + "</body></html>", encoding="utf-8")
print("index.html et artifact.html régénérés,", len(els), "éléments")
