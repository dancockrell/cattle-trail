from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image,ImageDraw

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent.parent/'source'/'spirit-lantern-prop-v1.png'
source=Image.open(SOURCE).convert('RGBA');pixels=np.array(source);rgb=pixels[:,:,:3].astype(np.int16)
key=((rgb[:,:,0]-rgb[:,:,1])>50)&((rgb[:,:,2]-rgb[:,:,1])>50)
pixels[key]=[0,0,0,0];pixels[~key,3]=255;rgba=Image.fromarray(pixels)
w,h=source.size;boxes=[(c*w//2,r*h//2,(c+1)*w//2,(r+1)*h//2) for r in range(2) for c in range(2)]
crops=[]
for box in boxes:
    region=rgba.crop(box);trim=region.getbbox();assert trim is not None
    crops.append((region.crop(trim),trim))
scale=14/max(crop.height for crop,_ in crops)
atlas=Image.new('RGBA',(128,32));review=Image.new('RGB',(1024,310),'#393d37');draw=ImageDraw.Draw(review)
states=['unlit','low_flame','warm_flame','spirit_flame'];frames=[]
for i,((crop,trim),box) in enumerate(zip(crops,boxes)):
    size=(round(crop.width*scale),round(crop.height*scale));offset=((32-size[0])//2,8)
    cell=Image.new('RGBA',(32,32));cell.paste(crop.resize(size,Image.Resampling.NEAREST),offset)
    cell.save(HERE/(states[i]+'.png'));atlas.paste(cell,(i*32,0))
    enlarged=cell.resize((256,256),Image.Resampling.NEAREST);review.paste(enlarged,(i*256,0),enlarged)
    draw.text((i*256+12,274),f'{i}: '+states[i],fill='white')
    frames.append({'index':i,'state':states[i],'source_row':i//2,'source_col':i%2,'source_cell_ltrb':list(box),'trim_ltrb_in_cell':list(trim),'atlas_rect_xywh':[i*32,0,32,32],'grip_anchor':[16,8],'scaled_size':list(size),'cell_offset':list(offset),'rgba_sha256':hashlib.sha256(cell.tobytes()).hexdigest()})
atlas.save(HERE/'atlas.png');review.save(HERE/'contact-sheet.png')
metadata={'schema_version':1,'status':'equipment_candidate_not_globally_admitted','equipment':'spirit_lantern','source':'kits/source/spirit-lantern-prop-v1.png','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'source_dimensions':[w,h],'reference':'kits/source/eleanor-lantern-v1.png','source_grid':[2,2],'texture':'atlas.png','atlas_size':[128,32],'cell':[32,32],'anchor':[16,8],'anchor_meaning':'Grip point at top centre of carrying handle, cell-local pixels, y down. Position cell at actor hand minus this anchor.','display_height_pixels':14,'frames':frames,'states':{name:{'frames':[i],'loop':False,'presentation':'static equipment state'} for i,name in enumerate(states)},'processing':{'common_scale':scale,'resampling':'nearest','alpha':'binary0/255; zeroRGBA keyed magenta','key_rule':'R-G>50 and B-G>50','whole_generated_lantern_only':True},'inspection':{'whole_prop':True,'no_hand_or_body':True,'same_handle_and_body_silhouette':True,'states_readable':'Darkglass, tinyamberwick, brightwarmflame, turquoise spiritflame.','notes':'Brass contours are retained at small native size. Candidate source has a near-frontal high view with top cap visible.'}}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
assert len({x['rgba_sha256'] for x in frames})==4
assert all(12<=x['scaled_size'][1]<=14 for x in frames)
print(json.dumps({'source':[w,h],'atlas':list(atlas.size),'cell':[32,32],'grip':[16,8],'display_heights':[x['scaled_size'][1] for x in frames]}))
