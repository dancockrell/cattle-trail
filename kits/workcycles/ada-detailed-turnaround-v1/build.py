"""Three static endviews, with native whole-figure crops and detailed derivatives."""
from pathlib import Path
import json,hashlib,math
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=HERE/'source.png';source=Image.open(p).convert('RGBA');frames=[];images=[]
for i,facing in enumerate(['southeast','east','northeast']):
    region=[round(i*source.width/3),0,round((i+1)*source.width/3),source.height]
    a=np.array(source.crop(tuple(region)));r=a[:,:,0].astype(int);g=a[:,:,1].astype(int);b=a[:,:,2].astype(int)
    bg=(r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8);a[:,:,3]=np.where(bg|(a[:,:,3]<128),0,255);a[a[:,:,3]==0]=0
    im=Image.fromarray(a);bounds=im.getbbox();assert bounds
    whole=im.crop(bounds);whole.save(HERE/f'{facing}-native.png');images.append(whole)
    frames.append({'index':i,'requested_facing':facing,'actual_facing':'pending_review','source_region_xyxy':region,'source_alpha_bounds_xyxy':list(bounds),'native_size':list(whole.size),'native_image':f'{facing}-native.png','native_rgba_sha256':hashlib.sha256(whole.tobytes()).hexdigest()})
atlas=Image.new('RGBA',(768,256));native_cell=math.ceil((max(max(im.size) for im in images)+32)/64)*64;native=Image.new('RGBA',(native_cell*3,native_cell))
for i,(whole,frame) in enumerate(zip(images,frames)):
    w=round(whole.width*160/whole.height);cell=Image.new('RGBA',(256,256));cell.paste(whole.resize((w,160),Image.Resampling.NEAREST),(128-w//2,80));cell.save(HERE/f'{frame["requested_facing"]}.png');atlas.paste(cell,(256*i,0))
    native.paste(whole,(native_cell*i+native_cell//2-whole.width//2,native_cell-16-whole.height));frame.update({'atlas_rect':[256*i,0,256,256],'anchor':[128,240],'alpha_bounds_xyxy':list(cell.getbbox()),'rgba_sha256':hashlib.sha256(cell.tobytes()).hexdigest(),'native_atlas_rect':[native_cell*i,0,native_cell,native_cell],'native_anchor':[native_cell//2,native_cell-16]})
atlas.save(HERE/'atlas.png');atlas.resize((1536,512),Image.Resampling.NEAREST).save(HERE/'preview.png');native.save(HERE/'atlas-native.png')
metadata={'id':'ada-detailed-turnaround-v1','character':'ada_mercer','age':22,'status':'detailed_static_endview_candidates','texture':'atlas.png','cell':[256,256],'anchor':[128,240],'figure_height':160,'native_texture':'atlas-native.png','native_cell':[native_cell,native_cell],'source':p.relative_to(ROOT).as_posix(),'source_sha256':sha(p),'prompt':'prompt.txt','identity_reference':'kits/wardrobe/ada-summer-v1/tied_workshirt_shorts-native.png','identity_reference_sha256':sha(ROOT/'kits/wardrobe/ada-summer-v1/tied_workshirt_shorts-native.png'),'frames':frames,'clips':{f'idle_{f}':{'frames':[i],'fps':1,'loop':True} for i,f in enumerate(['southeast','east','northeast'])},'transition':'Staticendviews only; no authoredturntween orwalkcycle.','provenance':{'tool':'builtin image_gen','attempts':1,'transforms':['magenta key','nativewholefigure crop','nativeatlas noresample','160pxnearest derivative in256cells']},'review':['No runtimechanges, renderedgame tests or40pxderivative.','1870smaterial cues: linen blouse, shortbrownwaistcoat, cottonbreeches, brassfastenings, leatherbeltboots; daringcut is WeirdWeststylization.']}
for f,actual in zip(frames,['southeast_front_oblique','east_side_profile','northeast_back_oblique']):
    f['actual_facing']=actual;f['facing_confidence']='high_for_static_endview'
metadata['review'].extend(['Source and160pxpreview show three distinct front/side/back orientations with head torso hips and boots rotating together.','Whole faces, feet, braid and toolbelt are visible without clipping. Wrench appears on visible hip in every view; exact anatomical attachment continuity remains unverified.','Planted endviews accepted as coherent static candidates; no tween or native-motion approval claimed.'])
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
print('ADA DETAILED ENDVIEWS PASS:3 whole nativecrops,160pxfigures/256cells; staticbank')
