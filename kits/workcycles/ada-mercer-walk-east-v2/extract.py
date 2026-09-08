from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image,ImageDraw

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent.parent
SOURCE=HERE.parent.parent/'source'/'ada-mercer-walk-east-v2.png'
source=Image.open(SOURCE).convert('RGBA');pixels=np.array(source);rgb=pixels[:,:,:3].astype(np.int16)
key=((rgb[:,:,0]-rgb[:,:,1])>50)&((rgb[:,:,2]-rgb[:,:,1])>50)
pixels[key]=[0,0,0,0];pixels[~key,3]=255;rgba=Image.fromarray(pixels)
w,h=source.size;boxes=[(c*w//2,r*h//2,(c+1)*w//2,(r+1)*h//2) for r in range(2) for c in range(2)]
crops=[]
for box in boxes:
    region=rgba.crop(box);trim=region.getbbox();assert trim is not None
    crops.append((region.crop(trim),trim))
scale=40/max(crop.height for crop,_ in crops)
atlas=Image.new('RGBA',(256,64));review=Image.new('RGB',(1024,320),'#3d4238');draw=ImageDraw.Draw(review)
directions=['contact_a_candidate','passing_a_candidate','contact_b_candidate','passing_b_candidate'];frames=[]
for i,((crop,trim),box) in enumerate(zip(crops,boxes)):
    size=(round(crop.width*scale),round(crop.height*scale));offset=((64-size[0])//2,61-size[1])
    cell=Image.new('RGBA',(64,64));cell.paste(crop.resize(size,Image.Resampling.NEAREST),offset)
    cell.save(HERE/(directions[i]+'.png'));atlas.paste(cell,(i*64,0))
    preview=cell.resize((256,256),Image.Resampling.NEAREST);review.paste(preview,(i*256,0),preview)
    draw.text((i*256+12,279),f'{i}: '+directions[i],fill='white')
    frames.append({'index':i,'direction':directions[i],'source_row':i//2,'source_col':i%2,'source_cell_ltrb':list(box),'trim_ltrb_in_cell':list(trim),'atlas_rect_xywh':[i*64,0,64,64],'anchor':[32,61],'scaled_size':list(size),'cell_offset':list(offset),'rgba_sha256':hashlib.sha256(cell.tobytes()).hexdigest()})
atlas.save(HERE/'atlas.png');review.save(HERE/'contact-sheet.png')
design=json.loads((ROOT/'design'/'characters.json').read_text(encoding='utf-8'))
ada=next(c for c in design['named_characters'] if c['id']=='ada_mercer')
assert ada['age']==22
metadata={'schema_version':1,'status':'new_identity_candidate_not_admitted','character_id':'ada_mercer','name':'Ada Mercer','age':22,'identity_authority':'design/characters.json#named_characters/ada_mercer','appearance':'Adult steam mechanic; auburn braid and brass goggles on hair; brown waist-length work jacket, cream open collar blouse, fitted olive riding trousers, toolbelt and boots.','source':'kits/source/ada-mercer-walk-east-v2.png','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'source_dimensions':[w,h],'style_reference':'kits/source/eleanor-lantern-v1.png','texture':'atlas.png','atlas_size':[256,64],'cell':[64,64],'anchor':[32,61],'frames':frames,'clips':{'idle_'+name:{'frames':[i],'fps':1,'loop':False,'presentation':'static directional pose'} for i,name in enumerate(directions)},'processing':{'shared_scale':scale,'max_whole_character_height':40,'resampling':'nearest','alpha':'binary0/255, zeroRGBA magenta pixels','whole_source_sprites_only':True},'inspection':{'whole_figures':True,'direction_mapping':'E front-oblique, NE rear-oblique, NW rear-oblique, S frontal.','identity':'Same braid/goggles/jacket/trousers silhouette across four directions.','limitations':['Northwest source shows two hanging tools, while other angles show one; toolbelt consistency needs review before final admission.','East is a front-oblique presentation rather than a strict lateral profile.','New identity candidate only; no existing Ada runtime sprite was replaced.'],'not_a_walk_cycle':True}}

metadata['status']='walk_candidate_not_admitted'
metadata['style_reference']='kits/source/ada-mercer-idle-v1.png'
metadata['actual_facing']='east'
for frame in metadata['frames']:
    frame['requested_phase']=frame.pop('direction')
    frame['direction']='east'
metadata['clips']={'walk_east_candidate':{'frames':[0,1,2,3],'durations_seconds':[0.14,0.14,0.14,0.14],'loop_proposed':True,'phase_order_verified':False}}
metadata['inspection']={'whole_figures':True,'direction_mapping':'All four east lateral views.','identity':'Auburn braid, goggles, brown jacket, cream blouse, olive trousers, single hanging wrench and boots retained.','observed_phases':['Wide contact-like stride','Low passing/narrow stance','Wide contact-like stride similar to0','Low passing/narrow stance similar to1'],'limitations':['Frames0/2 repeat similar arm swing and leg overlap; opposite anatomical lead leg is not clearly established.','Frames1/3 likewise show similar support/passing geometry.','Belt pouch position and jacket contours shift slightly.','Source row order is a proposal, not a verified complete gait.'],'runtime_admitted':False}

(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
assert len({f['rgba_sha256'] for f in frames})==4
print(json.dumps({'source':[w,h],'atlas':list(atlas.size),'cell':[64,64],'anchor':[32,61],'display_heights':[f['scaled_size'][1] for f in frames]}))
