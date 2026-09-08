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
offset=[128-round((550-bounds[0])*w/whole.width),84];frame=Image.new('RGBA',(256,256));frame.paste(whole.resize((w,160),Image.Resampling.NEAREST),tuple(offset));frame.save(HERE/'atlas.png');frame.resize((768,768),Image.Resampling.NEAREST).save(HERE/'preview.png')
refs=[('kits/workcycles/ada-detailed-turnaround-v1/southeast-native.png','identity and wardrobe'),('kits/wardrobe/ines-high-angle-v1/source.png','elevated camera only')]
metadata={'id':'ada-high-angle-v1','character':'ada_mercer','age':22,'status':'detailed_high_angle_master_candidate','texture':'atlas.png','cell':[256,256],'anchor':[128,244],'figure_height':160,'native_image':'ada-native.png','native_size':list(whole.size),'native_rgba_sha256':hashlib.sha256(whole.tobytes()).hexdigest(),'source':p.relative_to(ROOT).as_posix(),'source_sha256':sha(p),'prompt':'prompt.txt','references':[{'path':path,'sha256':sha(ROOT/path),'role':role} for path,role in refs],'source_alpha_bounds_xyxy':list(bounds),'alpha_bounds_xyxy':list(frame.getbbox()),'offset':offset,'atlas_rect':[0,0,256,256],'facing':'southeast','camera':'fixed elevated highthreequarter downward view','camera_confidence':'high relative to supplied camera reference; no calibrated angle claimed','clips':{'idle_southeast':{'frames':[0],'fps':1,'loop':True}},'review':['Crown and goggle tops substantially visible; tops of shoulders and boot insteps visible with head/torso foreshortening.','Camera follows Ines reference while retaining Ada auburn braid/goggles/linen waistcoat shorts/brassbuttons/toolbeltwrench.','Both feet and complete silhouette intact; exposedskin PG13 with opaque garmentcoverage.','Static master only, no animation or rendered-game approval.'],'provenance':{'tool':'builtin image_gen','attempts':1,'transforms':['magenta chromakey','wholefigure nativecrop retained','nearest160pxheight derivative','wholefigure offset in256cell anchor128244']}}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(frame)[:,:,3])).issubset({0,255})
print('ADA HIGH ANGLE PASS: nativewholemaster +160px256cell, camera/identity provenance saved')
