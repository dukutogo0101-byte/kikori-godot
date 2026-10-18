#!/usr/bin/env python3
"""Package coherent, immutable game releases and installable PWA metadata."""
import hashlib
import json
import re
import shutil
from pathlib import Path

root = Path('build/web')
for name in ['pwa.js', 'framebuffer_guard.js']:
    shutil.copyfile(Path('web') / name, root / name)
html = (root / 'index.html').read_text()
files = sorted(p for p in root.iterdir() if p.is_file() and p.name not in ['index.html', 'sw.js', 'manifest.webmanifest', '.nojekyll'] and not p.name.endswith('.import'))
# Include HTML and the worker policy so changing either produces a new release.
digest = hashlib.sha256(html.encode() + Path('web/sw.js').read_bytes())
for path in files:
    digest.update(path.name.encode())
    digest.update(path.read_bytes())
version = digest.hexdigest()[:16]
release = root / 'releases' / version
release.mkdir(parents=True, exist_ok=True)
for path in files:
    # Icons keep stable URLs for browser/app metadata.
    if path.name.startswith('app-icon-'):
        continue
    shutil.move(str(path), release / path.name)
    html = html.replace('"' + path.name + '"', '"releases/' + version + '/' + path.name + '"')
    html = html.replace("'" + path.name + "'", "'releases/" + version + '/' + path.name + "'")
# Godot derives WASM/worklet paths from its executable (which has no extension).
html = html.replace('"executable":"index"', '"executable":"releases/' + version + '/index"')
html = html.replace('window.kikoriBuild = null', 'window.kikoriBuild = ' + json.dumps(version))
(root / 'index.html').write_text(html)
manifest = {
    'id': './', 'name': 'KIKORI — 木こりと物流の森', 'short_name': 'KIKORI',
    'description': '木を切り、道を作り、森の資材を中央基地へ届けよう。',
    'lang': 'ja', 'start_url': './?app=1', 'scope': './', 'display': 'standalone',
    'background_color': '#173f36', 'theme_color': '#173f36',
    'icons': [{'src': f'app-icon-{size}.png', 'sizes': f'{size}x{size}', 'type': 'image/png', 'purpose': 'any maskable'} for size in [192, 512]],
    'categories': ['games'], 'prefer_related_applications': False,
}
(root / 'manifest.webmanifest').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
assets = ['./index.html', './manifest.webmanifest', './app-icon-192.png', './app-icon-512.png']
assets += ['./' + p.relative_to(root).as_posix() for p in sorted(release.iterdir())]
worker = Path('web/sw.js').read_text().replace('__VERSION__', json.dumps(version)).replace('__ASSETS__', json.dumps(assets))
(root / 'sw.js').write_text(worker)
(root / '.nojekyll').touch()
print('KIKORI_PWA_BUILD', version, 'precache_files', len(assets), 'bytes', sum(p.stat().st_size for p in root.rglob('*') if p.is_file()))
