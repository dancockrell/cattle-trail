"""Assemble selected complete whole-figure performances without painting or tweening."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent
META = json.loads((SOURCE / 'sheet4-metadata.json').read_text())
SELECTIONS = {
    'talk_southeast': ([24,25,26,27,28,29,30,31], [320,180,220,240,200,300,220,320],
        ['neutral','greeting','open palm','point','hand to chest','laugh','settle','neutral return'],
        'Expressive conversation performance; hand gestures are discrete poses, not smooth interpolated movement. Last and first poses both rest with lowered arms; face and skirt details vary.'),
    'field_care_southeast': ([16,17,18,19,20,21,22,23], [240,180,260,300,300,260,180,300],
        ['standing preparation','kneel with cloth','apply cloth','wrap forearm','press dressing','finish dressing','rise preparation','standing return'],
        'Complete standing-to-kneeling-to-standing role performance. Descent and ascent lack intermediate poses, and cloth is absent at endpoints. Suitably timed candidate; not a certified smooth loop.'),
    'idle_southeast': ([0,1,2,3], [400,300,300,400],
        ['rest A','rest B','rest C','rest D'],
        'Selected the first four consistent-stance whole figures; excluded the larger stance change in later row cells. Subtle contour drift remains, so this is not certified breathing motion.'),
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

assert sha(SOURCE / META['source']) == META['source_sha256']
summary=[]
for name, (indices, holds, phases, review) in SELECTIONS.items():
    dest=HERE/name
    dest.mkdir(parents=True, exist_ok=True)
    atlas=Image.new('RGBA',(256*len(indices),256))
    contact=Image.new('RGB',(256*4,284*((len(indices)+3)//4)), '#242321')
    draw=ImageDraw.Draw(contact)
    frames=[]
    records=[]
    for i,(index,hold,phase) in enumerate(zip(indices,holds,phases)):
        src=SOURCE/'sheet4-native'/f'{index:02d}.png'
        crop=Image.open(src).convert('RGBA')
        info=META['frames'][index]
        assert hashlib.sha256(crop.tobytes()).hexdigest()==info['native_rgba_sha256']
        frame=Image.new('RGBA',(256,256))
        frame.paste(crop,tuple(info['offset']))
        assert frame.crop((info['offset'][0],info['offset'][1],info['offset'][0]+crop.width,info['offset'][1]+crop.height)).tobytes()==crop.tobytes()
        atlas.paste(frame,(i*256,0))
        contact.paste(frame,((i%4)*256,(i//4)*284),frame)
        draw.text(((i%4)*256+8,(i//4)*284+260),f'{i}: source {index:02d} | {hold}ms | {phase}',fill='white')
        frames.append(frame)
        records.append({'index':i,'source_frame':index,'source_file':f'../../sheet4-native/{index:02d}.png','source_png_sha256':sha(src),'source_rgba_sha256':info['native_rgba_sha256'],'source_rect':info['source_rect'],'atlas_rect':[i*256,0,256,256],'anchor':[128,244],'duration_ms':hold,'phase':phase})
    assert len({r['source_rgba_sha256'] for r in records})==len(records)
    atlas.save(dest/'atlas.png')
    contact.save(dest/'contact-sheet.png')
    frames[0].save(dest/'loop.png',save_all=True,append_images=frames[1:],duration=holds,loop=0,disposal=0,blend=0,optimize=False)
    preview=Image.open(dest/'loop.png')
    assert preview.n_frames==len(frames)
    for i,frame in enumerate(frames):
        preview.seek(i)
        assert preview.convert('RGBA').tobytes()==frame.tobytes()
        assert round(preview.info['duration'])==holds[i]
    metadata={'version':1,'character':'eleanor','age':24,'status':'selected_performance_candidate','runtime_admitted':False,'source_sheet':'../../sheet4-source.png','source_sheet_sha256':META['source_sha256'],'source_metadata':'../../sheet4-metadata.json','source_metadata_sha256':sha(SOURCE/'sheet4-metadata.json'),'texture':'atlas.png','texture_sha256':sha(dest/'atlas.png'),'cell':[256,256],'anchor':[128,244],'native_pixel_preservation':True,'resampling':'none','frame_count':len(frames),'unique_source_figures':len(frames),'frames':records,'clips':{name:{'frames':list(range(len(frames))),'durations_seconds':[v/1000 for v in holds],'loop':True}},'seam_review':review,'timing_origin':'Authored review timing; source is an illustrated sheet, not a recorded performance.','checks':['Decoded APNG RGBA pixels equal assembled source frames.','Every selected source RGBA hash matches extraction metadata.','Every selected source figure is distinct; no duplicate padding or repeated endpoint.','Frame rectangles and timing match atlas and preview.']}
    (dest/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
    summary.append({'name':name,'frames':len(frames),'duration_ms':sum(holds),'metadata':f'{name}/metadata.json'})
(HERE/'manifest.json').write_text(json.dumps({'character':'eleanor','source_sheet':4,'runtime_admitted':False,'selected_performances':summary},indent=2)+'\n')
print('ELEANOR SELECTED LOOPS: 20 unique whole figures, three timed performances; pixel identity and decoded APNG timing verified.')
