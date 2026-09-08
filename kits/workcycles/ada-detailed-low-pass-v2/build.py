"""Whole low-pass proportion candidate from a native edit, no40pxinput."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=HERE/'source.png';im=Image.open(p).convert('RGBA');a=np.array(im);r=a[:,:,0].astype(int);g=a[:,:,1].astype(int);b=a[:,:,2].astype(int)
bg=(r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8);a[:,:,3]=np.where(bg|(a[:,:,3]<128),0,255);a[a[:,:,3]==0]=0
im=Image.fromarray(a);bounds=im.getbbox();assert bounds;whole=im.crop(bounds);whole.save(HERE/'whole-native.png');w=round(whole.width*160/whole.height)
hip_source_x=440;offset=[128-round((hip_source_x-bounds[0])*w/whole.width),84]
frame=Image.new('RGBA',(256,256));frame.paste(whole.resize((w,160),Image.Resampling.NEAREST),tuple(offset));frame.save(HERE/'whole-frame.png')
recovered=ROOT/'kits/workcycles/ada-detailed-recovered-walk-v1';comparison=Image.new('RGBA',(768,256))
for i,cell in enumerate([Image.open(recovered/'01-whole-frame.png').convert('RGBA'),Image.open(recovered/'03-whole-frame.png').convert('RGBA'),frame]):comparison.paste(cell,(256*i,0))
comparison.save(HERE/'comparison-atlas.png');comparison.resize((1536,512),Image.Resampling.NEAREST).save(HERE/'comparison.png')
metadata={'id':'ada-detailed-low-pass-v2','character':'ada_mercer','age':22,'status':'whole_lowpass_proportion_candidate_not_admitted','texture':'whole-frame.png','cell':[256,256],'anchor':[128,244],'figure_height':160,'source':p.relative_to(ROOT).as_posix(),'source_sha256':sha(p),'source_alpha_bounds_xyxy':list(bounds),'native_size':list(whole.size),'native_image':'whole-native.png','native_rgba_sha256':hashlib.sha256(whole.tobytes()).hexdigest(),'atlas_rect':[0,0,256,256],'offset':offset,'alpha_bounds_xyxy':list(frame.getbbox()),'rgba_sha256':hashlib.sha256(frame.tobytes()).hexdigest(),'hip_source_x_manual':hip_source_x,'inputs':[{'path':(recovered/name).relative_to(ROOT).as_posix(),'sha256':sha(recovered/name),'role':role} for name,role in [('03-native.png','wholepose edit target'),('01-native.png','identity and proportion reference')]],'prompt':'prompt.txt','phase':'far_leg_support_low_passing','duration_seconds':0.16,'timing':'provisional','facing':'east_side_profile','comparison_order':['recovered_near_support_reference','recovered_far_support_edit_target','new_proportion_candidate'],'provenance':{'tool':'builtin image_gen','attempts':1,'transforms':['magenta key','nativewholefigure crop','160pxnearestresize','wholefigure translation hip128 ground244']},'review':['Whole near leg still passes in front of grounded far leg, near boot leftward and above supporting sole.','Identity and jacket/trousers/wrench remain recognizable; exact original boot outlines were redrawn by generator.','No game tests,40pxinput,runtime replacement or bodypart compositing.']}
metadata['review'].append('Three-way160pxcomparison shows only slight proportion change. Head still reads smaller and lower body longer than near-support reference; objective not fully met, no replacement recommended automatically.')
metadata['proportion_result']='limited_change_not_resolved'
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('ADA DETAILED LOWPASS PASS: nativewholecrop +160px256cell, comparison/provenance saved')
