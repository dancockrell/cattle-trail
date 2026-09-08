"""Select Ines's actual elevated whole-figure master for a stationary encounter."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'kits/wardrobe/ines-high-angle-v1/atlas.png'
original=json.loads((source.parent/'actor-spec.json').read_text(encoding='utf-8'))
im=Image.open(source).convert('RGBA')
assert im.size==(256,256) and im.getbbox()
assert set(im.getchannel('A').get_flattened_data())<={0,255}
target=ROOT/'assets/ines.png';shutil.copyfile(source,target)
spec={key:original[key] for key in ['cell','anchor','pixels_per_world_unit','directional','default_facing','frames','frame_anchors','clips']}
spec.update(character_id='ines_vale',age=23,texture='res://assets/ines.png',
    status='stationary_room_encounter_review',runtime_admitted=True,
    source_texture=source.relative_to(ROOT).as_posix(),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    review='Elevated whole adult figure, opaque period-inspired clothing, complete boots and binary alpha inspected. Selected for stationary encounter only; no walk or turn animation is claimed.')
(ROOT/'assets/ines-art.json').write_text(json.dumps({'schema_version':1,'sprites':{'ines_vale':spec}},indent=2)+'\n',encoding='utf-8')
assert source.read_bytes()==target.read_bytes()
print('INES ART: exact retained whole-figure pixels, 256-cell, 128/244 anchor, density4, stationary encounter only')
