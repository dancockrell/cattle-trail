from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent
source=HERE/'source.png'
image=Image.open(source).convert('RGBA')
atlas=Image.new('RGBA',(512,256))
frames=[]
for i,direction in enumerate(['east_candidate','northeast']):
    box=(i*768,0,(i+1)*768,1024)
    cell=image.crop(box)
    a=np.array(cell)
    rgb=a[:,:,:3].astype(int)
    key=(rgb[:,:,0]>80)&(rgb[:,:,2]>80)&(rgb[:,:,1]<rgb[:,:,0]*.7)&(rgb[:,:,1]<rgb[:,:,2]*.7)
    a[key]=0
    a[~key,3]=255
    clean=Image.fromarray(a)
    bounds=clean.getbbox()
    assert bounds and bounds[0]>0 and bounds[2]<768 and bounds[1]>0 and bounds[3]<1024
    figure=clean.crop(bounds)
    figure.save(HERE/f'{direction}-native.png')
    width=round(figure.width*160/figure.height)
    small=figure.resize((width,160),Image.Resampling.NEAREST)
    cell=Image.new('RGBA',(256,256))
    cell.paste(small,(128-width//2,84))
    cell.save(HERE/f'{direction}.png')
    atlas.paste(cell,(i*256,0))
    frames.append({'index':i,'requested_facing':['east','northeast'][i],'observed_facing':['right-facing front-oblique; not strict east profile','back-right three-quarter/northeast'][i],'facing_confidence':['low for exact east','high for northeast'][i],'native_image':f'{direction}-native.png','image':f'{direction}.png','source_rect_xyxy':list(box),'trim_bounds_xyxy':list(bounds),'atlas_rect_xywh':[i*256,0,256,256],'anchor':[128,244],'status':'candidate_static_endview'})
atlas.save(HERE/'atlas.png')
atlas.resize((1024,512),Image.Resampling.NEAREST).save(HERE/'preview.png')
metadata={'schema_version':1,'id':'ines-high-angle-views-v1','character':'Ines Vale','age':23,'source':'source.png','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'reference':'kits/wardrobe/ines-high-angle-v1/ines-native.png','tool':'builtin image_gen','model':'not exposed','date':'2026-09-08','prompt':'prompt.txt','texture':'atlas.png','cell':[256,256],'anchor':[128,244],'figure_height':160,'native_cutouts_preserved':True,'frames':frames,'animations':{},'runtime_admitted':False,'elevation_review':'Both show crown, shoulder tops and foreshortened legs/boot top planes, retaining a raised camera comparable to the SE reference. Exact camera calibration unverified.','direction_gap':'Requested east remains too front-oblique; northeast is clearly distinct rear-right. No automatic turn intermediate admission.','transform':'Magenta key, whole-figure native trim, nearest-neighbor whole-figure160px scaling; no repaint or detached rig.'}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
print('INES HIGH ANGLE VIEWS PASS:2 whole native cutouts and160px/256cells anchor128,244; binaryalpha')
