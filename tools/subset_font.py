#!/usr/bin/env python3
"""Reproducible UI subset of SIL OFL Noto Sans CJK JP; no reserved font name."""
import argparse
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools import subset
parser=argparse.ArgumentParser()
parser.add_argument('source',help='Official NotoSansCJKjp-Regular.otf or NotoSansCJK-Regular.ttc')
args=parser.parse_args()
font=TTFont(args.source,fontNumber=0)
characters=set(chr(i) for i in range(32,127))
for folder,pattern in [('scripts','*.gd'),('web','*.html')]:
 for path in Path(folder).rglob(pattern): characters.update(path.read_text())
options=subset.Options();options.name_IDs=['*'];options.name_legacy=True;options.name_languages=['*']
subsetter=subset.Subsetter(options=options);subsetter.populate(unicodes=[ord(c) for c in characters]);subsetter.subset(font)
for record in font['name'].names:
 if record.nameID in [1,4,6,16,21]:
  record.string=('KikoriSans' if record.nameID==6 else 'Kikori Sans').encode(record.getEncoding())
font.save('assets/fonts/KikoriSans.otf')
print('Font subset:',len(characters),'requested characters;',Path('assets/fonts/KikoriSans.otf').stat().st_size,'bytes')
