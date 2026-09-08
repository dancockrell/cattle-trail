"""Whole-figure extraction at detailed master scale, never body-part assembly."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent
source=HERE/'source.png'
image=Image.open(source).convert('RGBA')
atlas=Image.new('RGBA',(384,384))
records=[]
for i in range(4):
    row,col=divmod(i,2)
    box=(round(col*image.width/2),round(row*image.height/2),round((col+1)*image.width/2),round((row+1)*image.height/2))
    cell=image.crop(box)
    a=np.array(cell)
    rgb=a[:,:,:3].astype(int)
    key=(rgb[:,:,0]>80)&(rgb[:,:,2]>80)&(rgb[:,:,1]<rgb[:,:,0]*.7)&(rgb[:,:,1]<rgb[:,:,2]*.7)
    a[key]=0
    a[~key,3]=255
    cell=Image.fromarray(a)
    bounds=cell.getbbox()
    assert bounds
    assert bounds[0]>0 and bounds[1]>0 and bounds[2]<cell.width and bounds[3]<cell.height,'Inspect clipped figure'
    figure=cell.crop(bounds)
    figure.save(HERE/f'outfit-{i+1:02d}-native.png')
    width=round(figure.width*160/figure.height)
    assert width<180
    figure=figure.resize((width,160),Image.Resampling.NEAREST)
    frame=Image.new('RGBA',(192,192))
    frame.paste(figure,(96-width//2,25))
    frame.save(HERE/f'outfit-{i+1:02d}.png')
    atlas.paste(frame,(col*192,row*192))
    records.append({'id':f'ines_summer_{i+1:02d}','age':23,'source_rect_xyxy':box,'trim_bounds_xyxy':list(bounds),'native_image':f'outfit-{i+1:02d}-native.png','image':f'outfit-{i+1:02d}.png','atlas_rect_xywh':[col*192,row*192,192,192],'anchor':[96,185],'status':'candidate_static_outfit','animations':{}})
atlas.save(HERE/'atlas.png')
atlas.resize((768,768),Image.Resampling.NEAREST).save(HERE/'preview.png')
metadata={'schema_version':1,'id':'spirit-scout-summer-v1','character':'Ines Vale','age':23,'reference':'kits/character-families/spirit-scout/master-v1.png','source':'source.png','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'tool':'builtin image_gen','model':'not exposed','date':'2026-09-08','prompt':'prompt.txt','texture':'atlas.png','cell':[192,192],'anchor':[96,185],'figure_height':160,'native_extractions_preserved':True,'frames':records,'animations':{},'runtime_admitted':False,'transform':'Magenta key; complete-figure trim preserved at native resolution; nearest-neighbor full-figure scale to160px inside192pxcell; no smoothing or repaint','scale_decision':'160px master output supersedes earlier40px request after user rejected coarse small-character presentation.'}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
print('INES SUMMER PASS:4 whole outfits, native cutouts plus160px figures in192px cells; hard binary alpha')
