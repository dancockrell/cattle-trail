"""Extract intact figures; preserve originals and key only border-connected checker."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_propagation

BASE=Path(__file__).resolve().parent
source=Image.open(BASE/'source.png').convert('RGBA')
atlas=Image.new('RGBA',(1024,512))
frames=[]
native=[]
for i in range(8):
    x,y=(i%4)*256,(i//4)*768
    a=np.array(source.crop((x,y,x+256,y+768)))
    rgb=a[:,:,:3].astype(int)
    neutral=(rgb.max(2)-rgb.min(2)<22)&(rgb.min(2)>165)
    seeds=np.zeros(neutral.shape,dtype=bool)
    seeds[0,:]=neutral[0,:];seeds[-1,:]=neutral[-1,:]
    seeds[:,0]=neutral[:,0];seeds[:,-1]=neutral[:,-1]
    background=binary_propagation(seeds,mask=neutral)
    a[:,:,3]=np.where(background,0,255)
    cut=Image.fromarray(a)
    box=cut.getbbox()
    assert box and box[0]>0 and box[2]<256 and box[1]>0 and box[3]<768, (i,box)
    trim=cut.crop(box)
    trim.save(BASE/f'frame-{i:02d}-native.png')
    native.append((trim,box))
# One scale for all figures preserves relative heights, including foot lift.
scale=160/max(im.height for im,_ in native)
for i,(trim,box) in enumerate(native):
    size=(round(trim.width*scale),round(trim.height*scale))
    offset=(128-size[0]//2,244-size[1])
    cell=Image.new('RGBA',(256,256))
    cell.alpha_composite(trim.resize(size,Image.Resampling.NEAREST),offset)
    cell.save(BASE/f'frame-{i:02d}.png')
    ax,ay=(i%4)*256,(i//4)*256
    atlas.alpha_composite(cell,(ax,ay))
    frames.append({'id':i,'source_rect':[i%4*256+box[0],i//4*768+box[1],trim.width,trim.height],
        'atlas_rect':[ax,ay,256,256],'anchor':[128,244],'offset':list(offset),
        'native_sha256':hashlib.sha256((BASE/f'frame-{i:02d}-native.png').read_bytes()).hexdigest()})
atlas.save(BASE/'atlas.png')
metadata={'version':1,'id':'eleanor_simple_v3','age':24,'source':'source.png','atlas':'atlas.png',
    'source_sha256':hashlib.sha256((BASE/'source.png').read_bytes()).hexdigest(),
    'cell':[256,256],'anchor':[128,244],'pixels_per_world_unit':4,'uniform_scale':scale,
    'frames':frames,'runtime_admitted':False,'animation_clips':{},
    'processing':'Border-connected neutral checker key; intact native crops; common nearest scale; bottom registration for static review only.',
    'limitations':['Enclosed checker patches may remain; white fabric protected by connectivity.',
        'Bottom registration is for static outfit comparison, not motion foot-lock.',
        'Repeated leading leg and braid-side drift; no complete walk or turn admitted.']}
(BASE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
spec={'schema_version':1,'character_id':'eleanor','age':24,'status':'static_costume_review',
    'runtime_admitted':False,'usage':'candidate_art',
    'texture':'res://kits/wardrobe/eleanor-simple-v3/atlas.png','cell':[256,256],
    'anchor':[128,244],'pixels_per_world_unit':4,'directional':False,'default_facing':'southeast',
    'frames':[{'index':f['id'],'atlas_rect':f['atlas_rect']} for f in frames],
    'clips':{f'pose_{i:02d}':{'frames':[i],'fps':1,'loop':False} for i in range(8)},
    'turn_transitions':{},'texture_sha256':hashlib.sha256((BASE/'atlas.png').read_bytes()).hexdigest(),
    'limits':['Static poses only; idle is a single held pose, not a breathing loop.',
        'No walking or turn animation is defined.','Not selected by the room.']}
spec['clips']['idle']={'frames':[0],'fps':1,'loop':False}
(BASE/'actor-spec.json').write_text(json.dumps(spec,indent=2)+'\n')
assert set(np.array(atlas)[:,:,3].flatten()) <= {0,255}
print('Extracted eight whole figures; binary alpha; shared scale; no animation admission.')
