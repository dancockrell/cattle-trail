"""Assemble whole authored carry poses in contact/passing order, preserving pixels."""
from pathlib import Path
import hashlib,json
from PIL import Image,ImageDraw
from build_lantern_art import validate_cell
ROOT=Path(__file__).resolve().parents[1]
inputs=[('eleanor-lantern-walk-v2','00-whole-frame.png','contact A'),
        ('eleanor-lantern-walk-v2','01-whole-frame.png','passing A'),
        ('eleanor-lantern-contact-v4','whole-frame.png','contact B'),
        ('eleanor-lantern-opposite-v3','whole-frame.png','passing B'),
        ('eleanor-lantern-v1','00-whole-frame.png','idle')]
atlas=Image.new('RGBA',(320,64));frames=[]
review=Image.new('RGB',(960,220),(101,111,60));draw=ImageDraw.Draw(review)
for index,(folder,file,label) in enumerate(inputs):
    source=ROOT/'kits/workcycles'/folder/file
    cell=Image.open(source).convert('RGBA')
    validate_cell(cell,[64,64],[32,61],{})
    atlas.paste(cell,(index*64,0))
    frames.append({'atlas_rect':[index*64,0,64,64],'input_cell':str(source.relative_to(ROOT)).replace('\\','/'),
        'input_cell_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'source_metadata':f'kits/workcycles/{folder}/metadata.json','phase':label,'anchor':[32,61]})
    enlarged=cell.resize((192,192),Image.Resampling.NEAREST)
    review.paste(enlarged,(index*192,24),enlarged);draw.text((index*192+6,6),label,fill='white')
destination=ROOT/'assets/lantern/eleanor_carry_east.png';atlas.save(destination)
spec={'texture':'res://assets/lantern/eleanor_carry_east.png','cell':[64,64],'anchor':[32,61],
    'frames':frames,'default_facing':'east','clips':{
    'idle':{'frames':[4],'fps':1,'loop':True},'idle_east':{'frames':[4],'fps':1,'loop':True},
    'walk_east':{'frames':[0,1,2,3],'fps':6.25,'loop':True,'durations':[.16,.16,.16,.16]}},
    'locomotion':{'nominal_speed':18.75},'status':'source_integrated_provisional_timing_no_motion_acceptance',
    'processing':'Exact whole RGBA cells, no pose repainting or body-part compositing.',
    'texture_sha256':hashlib.sha256(destination.read_bytes()).hexdigest()}
(ROOT/'assets/lantern/eleanor_carry_east.json').write_text(json.dumps(spec,indent=2)+'\n')
out=ROOT/'kits/workcycles/eleanor-lantern-east-v5';out.mkdir(exist_ok=True)
review.save(out/'sequence-sheet.png');atlas.save(out/'atlas.png')
(out/'metadata.json').write_text(json.dumps(spec,indent=2)+'\n')
print('ELEANOR CARRY PASS: five exact whole cells; ordered alternating contacts and passing; provisional timing')
