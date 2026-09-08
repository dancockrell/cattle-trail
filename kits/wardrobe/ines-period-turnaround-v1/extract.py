from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent
source=HERE/'source.png'
image=Image.open(source).convert('RGBA')
atlas=Image.new('RGBA',(768,256))
frames=[]
for i,direction in enumerate(['southeast','east','northeast']):
    box=(i*512,0,(i+1)*512,1024)
    cell=image.crop(box)
    a=np.array(cell)
    rgb=a[:,:,:3].astype(int)
    key=(rgb[:,:,0]>80)&(rgb[:,:,2]>80)&(rgb[:,:,1]<rgb[:,:,0]*.7)&(rgb[:,:,1]<rgb[:,:,2]*.7)
    a[key]=0
    a[~key,3]=255
    clean=Image.fromarray(a)
    bounds=clean.getbbox()
    assert bounds and bounds[0]>0 and bounds[2]<512 and bounds[1]>0 and bounds[3]<1024
    figure=clean.crop(bounds)
    figure.save(HERE/f'{direction}-native.png')
    width=round(figure.width*160/figure.height)
    small=figure.resize((width,160),Image.Resampling.NEAREST)
    cell=Image.new('RGBA',(256,256))
    cell.paste(small,(128-width//2,89))
    cell.save(HERE/f'{direction}.png')
    atlas.paste(cell,(i*256,0))
    frames.append({'index':i,'requested_facing':direction,'observed_facing':['front-right three-quarter','right profile','back-right three-quarter'][i],'facing_confidence':'high','native_image':f'{direction}-native.png','image':f'{direction}.png','source_rect_xyxy':list(box),'trim_bounds_xyxy':list(bounds),'atlas_rect_xywh':[i*256,0,256,256],'anchor':[128,249],'status':'candidate_static_endview'})
atlas.save(HERE/'atlas.png')
atlas.resize((1536,512),Image.Resampling.NEAREST).save(HERE/'preview.png')
metadata={'schema_version':1,'id':'ines-period-turnaround-v1','character':'Ines Vale','age':23,'source':'source.png','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'reference':'kits/wardrobe/spirit-scout-summer-v1/outfit-01-native.png','clothing_reference_approved_by_user':True,'approval_scope':'Prior reference coverage only; this new outfit, camera and runtime remain candidates.','tool':'builtin image_gen','model':'not exposed','date':'2026-09-08','prompt':'prompt.txt','texture':'atlas.png','cell':[256,256],'anchor':[128,249],'figure_height':160,'native_cutouts_preserved':True,'frames':frames,'animations':{},'runtime_admitted':False,'camera_limitation':'Distinct SE/E/NE body rotations are clear, but viewing elevation is closer to character turnaround/eye-level than requested game high three-quarter.','period_style':'Teal woven waistcoat with brass buttons/lacing, ivory gathered off-shoulder sleeves, plum split riding overskirt above opaque brown shorts, leather boots/satchel; stylized weird-west tailoring, not strict historical reconstruction.','transform':'Magenta key, complete-figure trim preserved natively, nearest-neighbor whole-figure scale to160px, no body repaint or assembly.'}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
print('INES PERIOD TURNAROUND PASS:3 complete static directions, native cutouts plus160px/256cells, binaryalpha')
