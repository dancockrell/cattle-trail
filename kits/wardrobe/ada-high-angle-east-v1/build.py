"""Extract the high-angle whole Ada master, preserving full native detail."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=HERE/'source.png';im=Image.open(p).convert('RGBA');a=np.array(im);r=a[:,:,0].astype(int);g=a[:,:,1].astype(int);b=a[:,:,2].astype(int)
bg=(r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8);a[:,:,3]=np.where(bg|(a[:,:,3]<128),0,255);a[a[:,:,3]==0]=0
im=Image.fromarray(a);bounds=im.getbbox();assert bounds;whole=im.crop(bounds);whole.save(HERE/'ada-native.png');w=round(whole.width*160/whole.height)
offset=[128-round((445-bounds[0])*w/whole.width),84];frame=Image.new('RGBA',(256,256));frame.paste(whole.resize((w,160),Image.Resampling.NEAREST),tuple(offset));frame.save(HERE/'atlas.png');frame.resize((768,768),Image.Resampling.NEAREST).save(HERE/'preview.png')
refs=[('kits/wardrobe/ada-high-angle-v1/ada-native.png','single wholebody edit target, identity and camera authority')]
metadata={'id':'ada-high-angle-east-v1','character':'ada_mercer','age':22,'status':'detailed_high_angle_master_candidate','texture':'atlas.png','cell':[256,256],'anchor':[128,244],'figure_height':160,'native_image':'ada-native.png','native_size':list(whole.size),'native_rgba_sha256':hashlib.sha256(whole.tobytes()).hexdigest(),'source':p.relative_to(ROOT).as_posix(),'source_sha256':sha(p),'prompt':'prompt.txt','references':[{'path':path,'sha256':sha(ROOT/path),'role':role} for path,role in refs],'source_alpha_bounds_xyxy':list(bounds),'alpha_bounds_xyxy':list(frame.getbbox()),'offset':offset,'atlas_rect':[0,0,256,256],'facing':'east','camera':'fixed elevated highthreequarter downward view','camera_confidence':'high relative to supplied camera reference; no calibrated angle claimed','clips':{'idle_east':{'frames':[0],'fps':1,'loop':True}},'review':['Facing and elevated camera require source/preview inspection.','Retains Ada master identity and period-material wardrobe.','Both feet and complete silhouette intact; exposedskin PG13 with opaque garmentcoverage.','Static master only, no animation or rendered-game approval.'],'provenance':{'tool':'builtin image_gen','attempts':1,'transforms':['magenta chromakey','wholefigure nativecrop retained','nearest160pxheight derivative','wholefigure offset in256cell anchor128244']}}
metadata['requested_facing']='east'
metadata['facing']='east_southeast_oblique_candidate'
metadata['camera_confidence']='elevated crown/shoulder/bootplanes retained; exact east bearing not established'
metadata['review'][0]='Head is closer to right profile with one visible eye, but torso and boottoes remain oblique down-right; partial rotation rather than strict east endpoint.'
metadata['review'].append('Broad crown and boot upperplanes maintain elevatedcamera. Complete boots visible; no authoredturn or runtime admission.')
metadata['clips']={'idle_oblique_candidate':{'frames':[0],'fps':1,'loop':True}}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(frame)[:,:,3])).issubset({0,255})
print('ADA HIGH ANGLE PASS: nativewholemaster +160px256cell, camera/identity provenance saved')
