"""Assemble whole-pose improvements with exact source pixels and explicit holds."""
from pathlib import Path
import hashlib
import json
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'kits/workcycles/ada-east-walk-v6'
OUT.mkdir(parents=True, exist_ok=True)
inputs = [
    ('ada-master-east-walk-v4/00-whole-frame.png', 'near_leg_contact'),
    ('ada-master-east-walk-v4/01-whole-frame.png', 'near_leg_support_passing'),
    ('ada-master-east-contact-v5/whole-frame.png', 'far_leg_contact_side_profile'),
    ('ada-master-east-walk-v4/03-whole-frame.png', 'far_leg_support_low_passing'),
]
atlas = Image.new('RGBA',(256,64))
records = []
for index,(path,phase) in enumerate(inputs):
    source = ROOT/'kits/workcycles'/path
    frame = Image.open(source).convert('RGBA')
    assert frame.size==(64,64) and frame.getbbox()
    assert set(frame.getchannel('A').tobytes()) <= {0,255}
    atlas.paste(frame,(index*64,0))
    records.append({'index':index,'phase':phase,'atlas_rect':[index*64,0,64,64],
      'source':source.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
      'rgba_sha256':hashlib.sha256(frame.tobytes()).hexdigest(),'duration_seconds':0.16})
atlas.save(OUT/'atlas.png')
atlas.resize((1536,384),Image.Resampling.NEAREST).save(OUT/'comparison.png')
metadata = {'version':1,'character':'ada_mercer','age':22,'cell':[64,64],'anchor':[32,61],
 'texture':'atlas.png','frames':records,'status':'rejected_user_quality', 'rejection_reason':'User rejected coarse detail in the four-pose sheet on 2026-09-08; not a production master.',
 'clips':{'walk_east_candidate':{'frames':[0,1,2,3],'fps':6.25,'loop':True,'admitted':False}},
 'changes':['Frame2 uses the corrected side-profile opposite contact.',
            'Frame3 uses the lowered passing foot, replacing the raised marching knee.'],
 'limits':['Whole figures still need consistent body volume, stride spacing and cadence review.',
           'These phase labels describe selected visual candidates, not in-game animation approval.'],
 'processing':'Exact whole-cell assembly, no repaint, rescale, mirroring or limb recombination'}
(OUT/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
print('ADA WALK V6 ASSEMBLED: four exact whole poses, corrected side contact and lowered passing foot')
