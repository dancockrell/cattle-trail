"""Pack selected whole-cart art without rescaling or altering source pixels."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / 'kits/workcycles/ada-steam-cart-v1'
metadata = json.loads((KIT / 'metadata-v2.json').read_text())
for name, expected in metadata['source_sha256'].items():
    assert hashlib.sha256((KIT / name).read_bytes()).hexdigest() == expected
source = Image.open(KIT / 'atlas-v2.png').convert('RGBA')
selected = [0, 2, 3, 4, 5]  # Exclude the mechanically inconsistent north draft.
headings = ['southeast', 'south', 'southwest', 'parked_southeast', 'north']
atlas = Image.new('RGBA', (480, 96))
frames = []
for ordinal, index in enumerate(selected):
    cell = source.crop((index*96, 0, (index+1)*96, 96))
    assert cell.getbbox() and set(cell.getchannel('A').tobytes()) <= {0, 255}
    atlas.paste(cell, (ordinal*96, 0))
    frames.append({'atlas_rect':[ordinal*96,0,96,96], 'source_index':index,
                   'observed_facing':headings[ordinal],
                   'rgba_sha256':hashlib.sha256(cell.tobytes()).hexdigest()})
atlas.save(ROOT / 'assets/ada-cart.png')
aliases = {'east':0, 'southeast':0, 'south':1, 'southwest':2, 'west':2,
           'north':4, 'northeast':4, 'northwest':4}
clips = {'idle':{'frames':[0], 'fps':1, 'loop':False},
         'parked':{'frames':[3], 'fps':1, 'loop':False}}
for name, index in aliases.items():
    for mode in ['idle', 'walk']:
        clips[mode+'_'+name] = {'frames':[index], 'fps':1, 'loop':False}
spec = {'version':1, 'status':'source_room_integration_sheet_reviewed',
        'sprites':{'ada_cart':{'texture':'res://assets/ada-cart.png','anchor':[48,90],
          'default_facing':'southeast','frames':frames,'clips':clips,
          'locomotion':{'nominal_speed':32},
          'heading_policy':'E uses SE, W uses SW, northern diagonals use N; exact observed views retained per frame.',
          'animation_status':'Static occupied directional views; wheel cycles and authored turns remain absent.'}},
        'provenance':{'source':(KIT/'atlas-v2.png').relative_to(ROOT).as_posix(),
          'sha256':hashlib.sha256((KIT/'atlas-v2.png').read_bytes()).hexdigest(),
          'selected_indices':selected,'rejected_indices':[1],
          'processing':'Exact whole-cell copies, no rescale or repaint',
          'validation':'Source hashes, alpha and exact pixels checked; no rendered game run'}}
(ROOT/'assets/ada-cart-art.json').write_text(json.dumps(spec,indent=2)+'\n',encoding='utf-8')
print('ADA CART ART PASS: four occupied views and one empty parked view, exact pixels, hashes and binary alpha')
