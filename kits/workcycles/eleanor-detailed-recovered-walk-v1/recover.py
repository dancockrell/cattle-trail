"""Recover original full-resolution poses; never resize a prior 40px runtime frame."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
h=Path(__file__).resolve().parent
root=h.parents[2]
original=json.loads((h.parent/'eleanor-east-v7/metadata.json').read_text())
# Manual pelvis centers in each full source crop, inferred from vest/skirt junction.
pelvis=[(310,400),(290,400),(590,795),(556,775)]
target_pelvis=(128,174)
atlas=Image.new('RGBA',(1024,256));frames=[]
for i,old in enumerate(original['frames']):
    source=root/old['source']
    digest=hashlib.sha256(source.read_bytes()).hexdigest()
    assert digest==old['source_sha256'],source
    crop=Image.open(source).convert('RGBA').crop(old['source_crop_xyxy'])
    crop.save(h/f'{i:02d}-source-crop.png')
    a=np.array(crop)
    r,g,b=[a[:,:,channel].astype(int) for channel in range(3)]
    key=(r-g>25)&(b-g>25)
    a[key]=0;a[~key,3]=255
    rgba=Image.fromarray(a)
    trim_box=old['keyed_trim_xyxy_in_crop']
    trim=rgba.crop(trim_box)
    assert trim.height>=160,'No tiny-frame upscaling'
    trim.save(h/f'{i:02d}-full-resolution.png')
    scale=160/trim.height
    size=(round(trim.width*scale),160)
    scaled_pelvis=(round((pelvis[i][0]-trim_box[0])*scale),round((pelvis[i][1]-trim_box[1])*scale))
    offset=(target_pelvis[0]-scaled_pelvis[0],target_pelvis[1]-scaled_pelvis[1])
    assert min(offset)>=0 and offset[0]+size[0]<=256 and offset[1]+160<=256
    cell=Image.new('RGBA',(256,256))
    cell.alpha_composite(trim.resize(size,Image.Resampling.NEAREST),offset)
    cell.save(h/f'{i:02d}-whole-frame.png')
    atlas.alpha_composite(cell,(i*256,0))
    frames.append({'index':i,'phase_intent':old['phase_intent'],'visible_evidence':old['visible_boot_identity'],
        'source':old['source'],'source_sha256':digest,'source_crop_xyxy':old['source_crop_xyxy'],
        'keyed_trim_xyxy_in_crop':trim_box,'full_resolution_crop':f'{i:02d}-full-resolution.png',
        'source_body_height':trim.height,'scale':scale,'size':list(size),'offset':list(offset),
        'manual_pelvis_in_crop':list(pelvis[i]),'pelvis_in_cell':list(target_pelvis),
        'atlas_rect':[i*256,0,256,256],'duration_seconds':.16,'status':'recovered_candidate'})
atlas.save(h/'atlas.png');atlas.save(h/'native-preview.png')
meta={'version':1,'character':'eleanor','age':24,'cell':[256,256],'anchor':[128,244],
    'pelvis_reference':[128,174],'body_height':160,'atlas':'atlas.png','frames':frames,
    'source_metadata':'kits/workcycles/eleanor-east-v7/metadata.json',
    'frame_order':[0,1,2,3],'review_clip':{'frames':[0,1,2,3],'durations_seconds':[.16]*4,'loop':True,'status':'provisional_contact_sheet_review'},
    'runtime_admitted':False,'animation_clips':{},'generation':'None; recovered existing original sources only.',
    'outfit':'Original Eleanor cream long-sleeve blouse, brown waistcoat, long indigo riding skirt and brown boots.',
    'actual_facing':'east_oblique_profile','observation':'All four native source poses located. Nearcontact has warm boot forwardright; oppositecontact has darkboot forwardright and warmboot trailingleft. Far-support passing shows warmboot crossing ahead of dark planted boot. Original face and outfit preserved.',
    'limitations':['Skirt obscures hip/knee reversal, so visible boots establish provisional phase evidence, not complete anatomical certification.','Passingnear pose partly hides farfoot.','Source art itself has coarse pixel clusters despite recovered160px output; this does not invent missing detail.','Manual pelvis centers approximate hidden anatomy; durations are provisional, no engine playback performed.'],
    'processing':'Hash-verified source crop, original binarymagenta rule, native transparenttrim, wholefigure nearest downsample160height, manually alignedpelvis with256padding. No40pxupscale, newgeneration, detachedlimb or pixelpainting.'}
(h/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
assert set(np.array(atlas)[:,:,3].flatten())<={0,255}
print('RECOVERED ELEANOR: 4originalsourceposes, heights438/445/878/870 ->160; pelvisaligned; binaryalpha; no missingphase source')
