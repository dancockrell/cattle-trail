from pathlib import Path
import json,hashlib
import numpy as np
from scipy import ndimage
from PIL import Image
h=Path(__file__).resolve().parent
row_names={2:['walk_northwest','walk_north','walk_northeast','walk_west'],3:['run_east','run_southeast','run_south','run_southwest'],4:['idle_breathing','lantern_carry_southeast','field_care','talk_gesture']}
row_notes={2:['Repeated broad strides, oppositelegsupport notcertified','Front/backfootchanges visible, passing/contact orderunverified','Similarlead repeats acrossrow','Repeatednearlead widecontact; no completeorderedwalkclaim'],3:['Extendedstride andflightvariation visible; nearlead repeats','Athleticposes differentiated, fullalternationnotcertified','Mostlyrepeatedforwardknee silhouette','Running gestures/legextension vary; orderedloopnotcertified'],4:['Subtlebody differences and one larger stancechange; no seamlessbreathingcertification','Lantern consistent screenleft, repeatedforwardleg silhouette','Visiblekneeling/cloth/forearmcareprogression, retainedwholefigures','Visible neutral/wave/openhand/point/laugh/nod/rest sequence']}
bundle=[{'sheet':1,'source':'source.png','metadata':'metadata.json','atlas':'atlas.png','figure_count':48}]
for number in [2,3,4]:
    rawpath=h/f'sheet{number}-source.png'
    raw=Image.open(rawpath).convert('RGBA');a=np.array(raw)
    key=(a[:,:,0]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,0].astype(float)*.7)
    a[key,3]=0;a[~key,3]=255
    labels,n=ndimage.label(~key,structure=np.ones((3,3)))
    boxes=[]
    for i,box in enumerate(ndimage.find_objects(labels),1):
        if box is None or np.count_nonzero(labels[box]==i)<2000:continue
        y,x=box;boxes.append((x.start,y.start,x.stop,y.stop))
    assert len(boxes)==32,(number,len(boxes))
    boxes.sort(key=lambda b:(b[1]+b[3])/2)
    boxes=sum([sorted(boxes[i:i+8]) for i in range(0,32,8)],[])
    rgba=Image.fromarray(a);rgba.save(h/f'sheet{number}-transparent.png')
    atlas=Image.new('RGBA',(2048,1024));frames=[]
    cropsdir=h/f'sheet{number}-native';cropsdir.mkdir(exist_ok=True)
    hashes=[]
    for i,box in enumerate(boxes):
        crop=rgba.crop(box)
        assert crop.width<256 and crop.height<244
        crop.save(cropsdir/f'{i:02d}.png')
        offset=(128-crop.width//2,244-crop.height)
        x,y=(i%8)*256,(i//8)*256
        atlas.alpha_composite(crop,(x+offset[0],y+offset[1]))
        digest=hashlib.sha256(crop.tobytes()).hexdigest();hashes.append(digest)
        frames.append({'index':i,'row':i//8,'column':i%8,'source_rect':[box[0],box[1],crop.width,crop.height],
            'atlas_rect':[x,y,256,256],'offset':list(offset),'native_size':[crop.width,crop.height],
            'native_rgba_sha256':digest,'requested_loop':row_names[number][i//8],
            'observation':row_notes[number][i//8],'status':'unverified_phase_candidate','duration_seconds_provisional':.16})
    atlas.save(h/f'sheet{number}-atlas.png')
    assert len(set(hashes))==32,'Do not silently pad a sheet with exactduplicatecrops'
    assert set(np.array(atlas)[:,:,3].flatten())<={0,255}
    meta={'version':1,'character':'eleanor','age':24,'sheet':number,'grid':[8,4],'figure_count':32,
        'source':rawpath.name,'source_size':list(raw.size),'source_sha256':hashlib.sha256(rawpath.read_bytes()).hexdigest(),
        'prompt':f'sheet{number}-prompt.txt','tool':'builtin image_gen','reference':'kits/wardrobe/eleanor-high-angle-v1/source.png',
        'cell':[256,256],'anchor':[128,244],'atlas':f'sheet{number}-atlas.png','frames':frames,
        'runtime_admitted':False,'animation_clips':{},'exact_unique_crops':len(set(hashes)),
        'limitations':['32separatelyillustratedwholefigures; exactuniquehash doesnotprove anatomicallydistinctphase.','Requested8phasecycles needorder/contact/loopcuration beforeadmission.','No duplicatedpadding created byextraction; rawgeneratednear-repeatposes preservedhonestly.'],
        'processing':'Magenta huekey and whole-connected-figure crop; nativepixels preserved noresampling;256cellpadding only.'}
    (h/f'sheet{number}-metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
    bundle.append({'sheet':number,'source':rawpath.name,'metadata':f'sheet{number}-metadata.json','atlas':f'sheet{number}-atlas.png','figure_count':32})
(h/'bundle.json').write_text(json.dumps({'character':'eleanor','age':24,'sheet_count':4,'whole_figure_count':144,'sheets':bundle,'status':'production_candidates_not_verified_complete_loops','external_paid_generation':False},indent=2)+'\n')
print('ELEANOR FOUR SHEETS PASS:48+32+32+32=144nativewholefigures;4uniquegenerations; allbinaryalpha; no pastedrepeatpadding; loopsunadmitted')
