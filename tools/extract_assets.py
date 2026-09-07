"""Deterministic cropping of approved art. Requires Pillow and numpy.
No synthesis, interpolation, palette replacement, or painted stand-ins.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np
import json, hashlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets'
OUT.mkdir(exist_ok=True)
sources = {i: Image.open(ROOT / f'source/reference_{i}.png').convert('RGBA') for i in range(3)}
manifest = {'schema_version': 1, 'world_size': [640,360], 'filter': 'nearest', 'alpha': 'binary >= 180', 'sprites': {}, 'sources': {}}
for p in (ROOT/'source').iterdir():
    if p.suffix in ('.png','.jpg','.mp4'):
        manifest['sources'][p.name] = {'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}

def cut(source, box, polygon=None):
    im = sources[source].crop(box)
    a = np.array(im)
    a[:,:,3] = np.where(a[:,:,3] >= 180, 255, 0)
    im = Image.fromarray(a)
    if polygon:
        mask=Image.new('L',im.size)
        ImageDraw.Draw(mask).polygon([(x-box[0],y-box[1]) for x,y in polygon],fill=255)
        im.putalpha(Image.fromarray(np.minimum(np.array(im.getchannel('A')),np.array(mask))))
    return im

def atlas(name, source, boxes, cell, factor, clips, polygons=None):
    sheet=Image.new('RGBA',(cell[0]*len(boxes),cell[1]))
    records=[]
    for i,box in enumerate(boxes):
        im=cut(source,box,polygons[i] if polygons else None)
        bounds=im.getbbox()
        if not bounds: raise ValueError(name)
        im=im.crop(bounds)
        im=im.resize((round(im.width*factor),round(im.height*factor)),Image.Resampling.NEAREST)
        offset=((cell[0]-im.width)//2,cell[1]-im.height-2)
        sheet.paste(im,(i*cell[0]+offset[0],offset[1]))
        records.append({'source_rect':list(box),'source_polygon':polygons[i] if polygons else None,'trim':list(bounds),'atlas_rect':[i*cell[0],0,*cell],'anchor':[cell[0]//2,cell[1]-2]})
    sheet.save(OUT/f'{name}.png')
    manifest['sprites'][name]={'texture':f'res://assets/{name}.png','source':f'reference_{source}.png','cell':cell,'anchor':[cell[0]//2,cell[1]-2],'scale_from_source':factor,'frames':records,'clips':clips}

# Hand-traced subject boundaries exclude adjacent cattle and combined group shadows.
rider=[(25,413),(21,372),(36,324),(76,283),(81,239),(91,214),(109,198),(147,197),(157,225),(185,222),(192,249),(184,280),(164,295),(158,326),(136,360),(125,382),(79,406)]
shifts=[(0,0),(434,-11),(872,-11),(1321,-14)]
rpolys=[[(x+dx,y+dy) for x,y in rider] for dx,dy in shifts]
rboxes=[(18+dx,182+dy,195+dx,415+dy) for dx,dy in shifts]
atlas('rider',0,rboxes,[64,80],.30,{'idle':{'frames':[0],'fps':1,'loop':True},'ride':{'frames':[0,1,2,3],'fps':7,'loop':True}},rpolys)
manifest['sprites']['rider']['directions']={'east':'source northeast','west':'horizontal mirror of northeast','north':'northeast source pose','south':'northeast source pose; missing true south frames'}
cow=[(283,165),(284,147),(301,137),(335,126),(349,104),(374,98),(385,117),(415,111),(430,109),(430,139),(416,149),(412,180),(397,209),(369,222),(338,240),(310,241),(300,216),(301,186)]
cshifts=[(0,0),(435,-6),(879,-6),(1321,-13)]
atlas('longhorn',0,[(263+dx,92+dy,435+dx,245+dy) for dx,dy in cshifts],[58,50],.30,{'idle':{'frames':[0],'fps':1,'loop':True},'walk':{'frames':[0,1,2,3],'fps':5,'loop':True}},[[(x+dx,y+dy) for x,y in cow] for dx,dy in cshifts])
# Distinct colors from the same first grouping.
white=[(267,291),(277,270),(299,252),(326,247),(355,234),(370,227),(385,235),(385,255),(369,270),(365,298),(347,317),(326,327),(296,337),(272,330)]
atlas('cream',0,[(263,221,393,341)],[58,50],.35,{'idle':{'frames':[0],'fps':1,'loop':True},'walk':{'frames':[0],'fps':1,'loop':True}},[white])
spotted=[(185,266),(195,226),(222,201),(255,193),(265,176),(282,172),(290,185),(309,182),(317,194),(307,215),(291,223),(281,248),(262,271),(238,287),(212,292),(193,286)]
atlas('spotted',0,[(178,167,323,299)],[58,50],.34,{'idle':{'frames':[0],'fps':1,'loop':True},'walk':{'frames':[0],'fps':1,'loop':True}},[spotted])
atlas('eleanor',1,[(21,329,59,389),(66,329,103,389),(109,329,146,389)],[36,48],.72,{'idle':{'frames':[0,1,0,2],'fps':2,'loop':True},'talk':{'frames':[1,2],'fps':3,'loop':True}})
atlas('rustler',1,[(23,447,59,507),(67,447,105,507),(151,447,195,507),(464,447,513,507)],[40,48],.72,{'idle':{'frames':[0],'fps':1,'loop':True},'walk':{'frames':[1,2],'fps':5,'loop':True},'shoot':{'frames':[3],'fps':1,'loop':True}})
atlas('wagon',1,[(20,917,147,996)],[112,72],.85,{'idle':{'frames':[0],'fps':1,'loop':True}})

# Terrain strips: only empty ground from the approved concept frame; actors are never baked into the room.
video=Image.open(ROOT/'source/concept-start.jpg').convert('RGB')
terrain=Image.new('RGB',(640,360))
patches={'grass':(325,4,540,99),'road':(347,342,1025,398)}
for kind,box in patches.items():
    patch=video.crop(box).resize(((box[2]-box[0])//2,(box[3]-box[1])//2),Image.Resampling.NEAREST)
    patch.save(OUT/f'{kind}.png')
    manifest.setdefault('terrain',{})[kind]={'source':'concept-start.jpg','source_rect':list(box),'reduction':2}
grass=Image.open(OUT/'grass.png'); road=Image.open(OUT/'road.png')
for y in range(0,360,grass.height):
    for x in range(0,640,grass.width): terrain.paste(grass,(x,y))
for y in range(115,265,road.height):
    for x in range(0,640,road.width): terrain.paste(road,(x,y))
terrain.paste(video.crop((0,0,1280,100)).resize((640,50),Image.Resampling.NEAREST),(0,0))
bottom=video.crop((125,622,1005,720)).resize((440,49),Image.Resampling.NEAREST)
terrain.paste(bottom,(0,311)); terrain.paste(bottom,(440,311))
terrain.save(OUT/'room.png')
manifest['terrain']['border_strips']={'source':'concept-start.jpg','top':[0,0,1280,100],'bottom':[125,622,1005,720],'reduction':2}
# UI frame extracted from the concept, emptied by sampling its existing paper interior.
panel=video.crop((1030,609,1279,719)).resize((249,110),Image.Resampling.NEAREST)
paper=video.crop((1150,700,1190,706)).resize((229,86),Image.Resampling.NEAREST)
panel.paste(paper,(10,12)); panel.save(OUT/'panel.png')
manifest['ui']={'panel':{'source':'concept-start.jpg','rect':[1030,609,1279,719],'interior_sample':[1150,700,1190,706]}}
(OUT/'sprites.json').write_text(json.dumps(manifest,indent=2)+'\n')
# A large checker-free alpha review, including every atlas frame.
review=Image.new('RGB',(800,500),(131,132,74)); d=ImageDraw.Draw(review)
y=8
for name,spec in manifest['sprites'].items():
    d.text((8,y),name,fill='white'); im=Image.open(OUT/f'{name}.png'); review.paste(im,(115,y),im); y+=max(im.height,48)+8
review.save(ROOT/'art-review.png')
print('Extracted',len(manifest['sprites']),'atlases, with exact source rectangles, anchors, and clips.')
