"""Build an offline viewer of actual generated sheets and their chronological rows."""
from pathlib import Path
import json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'kits/big-sheets'
records=[]
for path in sorted(BASE.rglob('*metadata.json')):
    if 'selected-loops' in path.parts: continue
    m=json.loads(path.read_text(encoding='utf-8'))
    atlas=path.parent/m.get('atlas',m.get('texture','atlas.png'))
    if not atlas.exists(): continue
    frames=m.get('frames',m.get('items',[]))
    frames=[dict(f,atlas_rect=f.get('atlas_rect',f.get('atlas_rect_xywh'))) for f in frames]
    if not frames or any(f['atlas_rect'] is None for f in frames): continue
    relative=path.parent.relative_to(BASE).as_posix()
    rows=[]
    for start in range(0,len(frames),8):
        f=frames[start]
        label=f.get('requested_row',f.get('requested_group',f.get('category',f'Row {start//8+1}')))
        rows.append({'label':str(label),'frames':[f['atlas_rect'] for f in frames[start:start+8]]})
    suffix='' if path.name=='metadata.json' else ' / '+path.stem.replace('-metadata','')
    records.append({'name':relative.replace('-',' ').replace('/',' / ')+suffix,'atlas':atlas.relative_to(BASE).as_posix(),
        'source':relative+'/'+m.get('source','source.png'),'prompt':relative+'/'+m.get('prompt','prompt.txt'),'metadata':path.relative_to(BASE).as_posix(),
        'rows':rows,'count':len(frames),'dimensions':Image.open(atlas).size})
loops=[]
for path in sorted(BASE.rglob('*')):
    if 'selected-loops' not in path.parts or path.suffix.lower() not in ['.png','.apng']: continue
    with Image.open(path) as im:
        if getattr(im,'n_frames',1)>1:
            loops.append({'name':str(path.relative_to(BASE)).replace('\\',' / '),'path':path.relative_to(BASE).as_posix(),'frames':im.n_frames})
template='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Cattle Trail — Full Sheet Workshop</title><style>
*{box-sizing:border-box}body{margin:0;background:#211d19;color:#f2dfb6;font:16px system-ui}main{max-width:1400px;margin:auto;padding:24px}h1{font-size:28px}p{line-height:1.5;color:#cbbb9b}select,button,input{font:inherit;min-height:44px;background:#3a3026;color:#ffe6b5;border:1px solid #806b4b;border-radius:5px;padding:8px}a{color:#e9be69}nav{display:flex;gap:10px;flex-wrap:wrap;margin:16px 0}section{display:grid;grid-template-columns:minmax(290px,440px) 1fr;gap:20px}.stage{background:#302d29;border:1px solid #756448;display:grid;place-items:center;min-height:300px;overflow:auto}canvas,img{image-rendering:pixelated}canvas{width:384px;height:384px;max-width:100%}.sheet{width:100%;display:block;background:#302d29}label{display:flex;gap:8px;align-items:center}output{font-variant-numeric:tabular-nums}.details{font-size:14px} @media(max-width:760px){section{grid-template-columns:1fr}main{padding:14px}}
</style><main><h1>Cattle Trail · Full Sheet Workshop</h1><p id="summary"></p>
<nav><label>Sheet <select id="sheet"></select></label><label>Sequence <select id="row"></select></label></nav>
<section><div><div class="stage"><canvas width="256" height="256" aria-label="Actual sprite row playback"></canvas></div>
<nav><button id="play">Pause</button><button id="prev" aria-label="Previous frame">←</button><button id="next" aria-label="Next frame">→</button><output id="position"></output></nav>
<nav><label><input id="reverse" type="checkbox"> Reverse playback</label><label><input id="pingpong" type="checkbox"> Ping-pong preview</label></nav>
<label>Speed <input id="fps" type="range" min="2" max="16" value="8"><output id="rate">8 fps</output></label>
<p class="details">These are actual extracted cells. Reverse and ping-pong change preview order only; source frames and metadata remain unchanged. Ping-pong retraces the row without holding either endpoint twice. Preview playback does not certify a seamless loop. Missing or repeated phases remain visible.</p><nav><a id="source">Original sheet</a><a id="prompt">Exact prompt</a><a id="metadata">Sprite metadata</a></nav></div>
<div><img id="full" class="sheet" alt="Full transparent sprite atlas"></div></section><h2>Selected performances</h2><p>Timed source-frame selections with compatible return poses. These candidates retain the documented contour and transition limitations.</p><div id="loops" style="display:flex;flex-wrap:wrap;gap:16px"></div></main>
<script>const sheets=DATA;const loops=LOOPS;const $=s=>document.querySelector(s);const select=$('#sheet'),rows=$('#row'),canvas=$('canvas'),ctx=canvas.getContext('2d');let sheet,row,frame=0,playing=true,last=0,travel=1;const art=new Image();let loading=false;
for(const loop of loops){const a=document.createElement('a');a.href=loop.path;a.style.width='256px';const im=document.createElement('img');im.src=loop.path;im.alt=loop.name;im.loading='lazy';im.style.width='256px';a.append(im,document.createTextNode(loop.name+' · '+loop.frames+' frames'));$('#loops').append(a)}
$('#summary').textContent=sheets.length+' full sheets · '+sheets.reduce((n,s)=>n+s.count,0)+' extracted cells · original artwork and row playback';
sheets.forEach((s,i)=>select.add(new Option(s.name+' · '+s.count+' cells',i)));
function draw(){if(loading||!row)return;const r=row.frames[frame];ctx.imageSmoothingEnabled=false;ctx.clearRect(0,0,256,256);ctx.drawImage(art,...r,0,0,256,256);$('#position').textContent=(frame+1)+' / '+row.frames.length;}
function chooseRow(){row=sheet.rows[Number(rows.value)];travel=$('#reverse').checked?-1:1;frame=travel<0?row.frames.length-1:0;last=performance.now();draw();}
function choose(){sheet=sheets[Number(select.value)];rows.replaceChildren();sheet.rows.forEach((r,i)=>rows.add(new Option((i+1)+'. '+r.label,i)));loading=true;art.onload=()=>{loading=false;draw()};art.src=sheet.atlas;$('#full').src=sheet.atlas;for(const id of ['source','prompt','metadata'])$('#'+id).href=sheet[id];chooseRow();}
select.onchange=choose;rows.onchange=chooseRow;$('#play').onclick=()=>{playing=!playing;$('#play').textContent=playing?'Pause':'Play';last=performance.now()};function step(delta){if(!row)return;playing=false;$('#play').textContent='Play';frame=(frame+delta+row.frames.length)%row.frames.length;travel=$('#reverse').checked?-1:1;last=performance.now();draw()}$('#prev').onclick=()=>step(-1);$('#next').onclick=()=>step(1);$('#fps').oninput=()=>$('#rate').textContent=$('#fps').value+' fps';
$('#reverse').onchange=()=>{travel=-travel;last=performance.now()};$('#pingpong').onchange=()=>{travel=$('#reverse').checked?-1:1;last=performance.now()};
function advance(count){const n=row.frames.length;if(n<2){frame=0;return}if($('#pingpong').checked){const period=2*(n-1);const phase=((travel>0?frame:period-frame)+count)%period;frame=phase<n?phase:period-phase;travel=phase<n-1?1:-1}else{const direction=$('#reverse').checked?-1:1;frame=((frame+direction*count)%n+n)%n;travel=direction}}
function tick(now){if(playing&&row&&!loading){const dt=1000/Number($('#fps').value);if(now-last>=dt){const count=Math.floor((now-last)/dt);advance(count);last+=count*dt;draw()}}requestAnimationFrame(tick)}if(sheets.length)choose();requestAnimationFrame(tick);
</script></html>'''
(BASE/'index.html').write_text(template.replace('DATA',json.dumps(records).replace('<','\\u003c')).replace('LOOPS',json.dumps(loops).replace('<','\\u003c')),encoding='utf-8')
(BASE/'catalog.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8')
print(f'WORKSHOP BUILT: {len(records)} sheets, {sum(r["count"] for r in records)} extracted cells')
