"""Check the actual atlas contract; does not claim artistic acceptance."""
from pathlib import Path
from PIL import Image
import json, hashlib
import numpy as np

root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'kits/manifest.json').read_text())
report={'schema_version':1,'checks':[],'families':{},'visual_acceptance':False}
total=0
for name,spec in manifest['families'].items():
    im=Image.open(root/spec['texture'].replace('res://',''))
    assert im.mode=='RGBA',name
    pixels=np.array(im)
    assert set(np.unique(pixels[:,:,3])).issubset({0,255}),name
    hashes=[]
    for frame in spec['frames']:
        x,y,w,h=frame['atlas_rect']
        assert w==spec['cell'][0] and h==spec['cell'][1]
        assert x>=0 and y>=0 and x+w<=im.width and y+h<=im.height
        crop=im.crop((x,y,x+w,y+h))
        bounds=crop.getbbox(); assert bounds,name
        assert bounds[0]>0 and bounds[1]>=0 and bounds[2]<w and bounds[3]<h,name
        assert 0<=frame['anchor'][0]<w and 0<=frame['anchor'][1]<h
        original=root/frame['source']
        assert hashlib.sha256(original.read_bytes()).hexdigest()==frame['source_sha256'],name
        source_image=Image.open(original)
        left,top,right,bottom=frame['source_rect']
        assert 0<=left<right<=source_image.width and 0<=top<bottom<=source_image.height
        hashes.append(hashlib.sha256(crop.tobytes()).hexdigest())
    for clip in spec['clips'].values():
        assert clip['frames'] and clip['fps']>0
        assert all(0<=n<len(spec['frames']) for n in clip['frames'])
    unique=len(set(hashes))
    assert unique==len(hashes),f'{name}: exact duplicate cells cannot count toward richness'
    total+=len(hashes)
    report['families'][name]={'extracted':len(hashes),'unique_rgba_cells':unique,'clips':len(spec['clips']),'cell':spec['cell'],'binary_alpha':True,'source_hashes_verified':True}
report['checks']=['RGBA alpha binary','every cell nonempty and within atlas','consistent dimensions and anchors','original file hashes match','source crop bounds valid','clips reference present frames at positive rates','no exact duplicate RGBA cells']
report['total_extracted']=total
assert total==manifest['total_extracted']
(root/'kits/validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(f'KIT CONTRACT PASS: {len(report["families"])} families, {total} unique RGBA cells; visual acceptance remains separate.')
