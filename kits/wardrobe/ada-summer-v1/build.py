"""Detailed whole wardrobe extraction: preserve native crops; never reduce to40px."""
from pathlib import Path
import hashlib,json,math
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=HERE/'source.png';source=Image.open(p).convert('RGBA');frames=[];whole_images=[]
names=['tied_workshirt_shorts','waistcoat_halter_shorts','offshoulder_wrapskirt','openback_halter_shorts']
for i,name in enumerate(names):
    col,row=i%2,i//2;region=[round(col*source.width/2),round(row*source.height/2),round((col+1)*source.width/2),round((row+1)*source.height/2)]
    im=source.crop(tuple(region));a=np.array(im);r=a[:,:,0].astype(int);g=a[:,:,1].astype(int);b=a[:,:,2].astype(int)
    bg=(r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8)
    a[:,:,3]=np.where(bg|(a[:,:,3]<128),0,255);a[a[:,:,3]==0]=0
    im=Image.fromarray(a);bounds=im.getbbox();assert bounds
    whole=im.crop(bounds);whole.save(HERE/f'{name}-native.png');whole_images.append(whole)
    frames.append({'index':i,'outfit':name,'age':22,'facing':'northeast_back_oblique' if i==3 else 'east_front_oblique','source_region_xyxy':region,'source_alpha_bounds_xyxy':list(bounds),'native_size':list(whole.size),'native_image':f'{name}-native.png','native_rgba_sha256':hashlib.sha256(whole.tobytes()).hexdigest()})
atlas=Image.new('RGBA',(512,512));native_cell=math.ceil((max(max(im.size) for im in whole_images)+32)/64)*64;native_atlas=Image.new('RGBA',(native_cell*2,native_cell*2))
for i,(whole,frame) in enumerate(zip(whole_images,frames)):
    col,row=i%2,i//2;w=round(whole.width*160/whole.height)
    detailed=Image.new('RGBA',(256,256));detailed.paste(whole.resize((w,160),Image.Resampling.NEAREST),(128-w//2,80));detailed.save(HERE/f'{names[i]}-160.png');atlas.paste(detailed,(col*256,row*256))
    native_offset=[native_cell//2-whole.width//2,native_cell-16-whole.height];native_atlas.paste(whole,(col*native_cell+native_offset[0],row*native_cell+native_offset[1]))
    frame.update({'atlas_rect':[col*256,row*256,256,256],'anchor':[128,240],'detail_height':160,'native_atlas_rect':[col*native_cell,row*native_cell,native_cell,native_cell],'native_anchor':[native_cell//2,native_cell-16],'alpha_bounds_xyxy':list(detailed.getbbox())})
atlas.save(HERE/'atlas-160.png');native_atlas.save(HERE/'atlas-native.png');atlas.resize((1024,1024),Image.Resampling.NEAREST).save(HERE/'preview-160.png')
metadata={'id':'ada-summer-v1','character':'ada_mercer','age':22,'status':'high_detail_wardrobe_candidates','source':p.relative_to(ROOT).as_posix(),'source_sha256':sha(p),'prompt':'prompt.txt','identity_reference':'kits/character-families/mechanic/master.png','identity_reference_sha256':sha(ROOT/'kits/character-families/mechanic/master.png'),'texture':'atlas-160.png','cell':[256,256],'anchor':[128,240],'native_texture':'atlas-native.png','native_cell':[native_cell,native_cell],'native_anchor':[native_cell//2,native_cell-16],'frames':frames,'clips':{name:{'frames':[i],'fps':1,'loop':True} for i,name in enumerate(names)},'motion':'Four independent wardrobes; no walk or turn sequence.','resolution_authority':'Latest user rejects40px reduction; native whole crops retained and160px detailed candidates delivered. No40px derivative produced.','provenance':{'tool':'builtin image_gen','attempts':1,'transforms':['magenta key with binary alpha','wholefigure crop preserved atnative dimensions','native atlas placement without resampling','separate160pxheight nearest-only derivative in256cells']},'review':['Adult Ada identity and opaque upperPG13 wardrobe.','No runtime replacement or game tests.']}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(f'ADA SUMMER DETAIL PASS:4 native wholecrops +160px candidates,256cells; nativeatlas{native_cell*2}px; no40px output')
