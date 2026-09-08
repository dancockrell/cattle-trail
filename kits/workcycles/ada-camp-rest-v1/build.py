"""Whole-character rest states with actual crate props; no animation synthesis."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=HERE/'source.png';source=Image.open(p).convert('RGBA');atlas=Image.new('RGBA',(128,64));frames=[]
for i,(state,height) in enumerate([('seated_mug',32),('standing_mug',40)]):
    region=[round(i*source.width/2),0,round((i+1)*source.width/2),source.height]
    im=source.crop(tuple(region));a=np.array(im);r=a[:,:,0].astype(int);g=a[:,:,1].astype(int);b=a[:,:,2].astype(int)
    bg=(r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8)
    a[:,:,3]=np.where(bg|(a[:,:,3]<128),0,255);a[a[:,:,3]==0]=0
    im=Image.fromarray(a);bounds=im.getbbox();assert bounds
    whole=im.crop(bounds);whole.save(HERE/f'{state}-trim.png');w=round(whole.width*height/whole.height);assert w<60
    # Align Ada's feet, not the combined character-plus-crate bounding center.
    foot_source=[(528,913),(1200,875)][i]
    offset=[32-round((foot_source[0]-region[0]-bounds[0])*w/whole.width),61-round((foot_source[1]-bounds[1])*height/whole.height)]
    frame=Image.new('RGBA',(64,64));frame.paste(whole.resize((w,height),Image.Resampling.NEAREST),tuple(offset));frame.save(HERE/f'{state}.png');atlas.paste(frame,(64*i,0))
    frames.append({'index':i,'state':state,'atlas_rect':[64*i,0,64,64],'anchor':[32,61],'source_ground_anchor_estimate':list(foot_source),'source_region_xyxy':region,'source_alpha_bounds_xyxy':list(bounds),'alpha_bounds_xyxy':list(frame.getbbox()),'figure_and_crate_height':height,'offset':offset,'rgba_sha256':hashlib.sha256(frame.tobytes()).hexdigest()})
atlas.save(HERE/'atlas.png');atlas.resize((1024,512),Image.Resampling.NEAREST).save(HERE/'comparison.png')
metadata={'id':'ada-camp-rest-v1','character':'ada_mercer','age':22,'texture':'atlas.png','cell':[64,64],'anchor':[32,61],'status':'static_rest_state_candidates','facing':'east_oblique','source':p.relative_to(ROOT).as_posix(),'source_sha256':sha(p),'prompt':'prompt.txt','identity_reference':'kits/character-families/mechanic/master.png','identity_reference_sha256':sha(ROOT/'kits/character-families/mechanic/master.png'),'frames':frames,'clips':{'rest_seated_mug':{'frames':[0],'fps':1,'loop':True},'rest_standing_mug':{'frames':[1],'fps':1,'loop':True}},'transition':'state switch only; no sit/stand animation supplied','review':['Two separate complete whole-character compositions including wooden crate.','Standing height40, seatedheight32, binaryalpha andnearestsampling.','Staticstates only; no rendered-game or motion tests.'],'provenance':{'tool':'builtin image_gen','attempts':1,'transforms':['magenta chromakey','wholecomposition crop','nearest32/40height','64cellanchor32,61']}}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
print('ADA CAMP REST PASS:2 whole staticstates, crateincluded,64cells32/61anchors, binaryalpha')
