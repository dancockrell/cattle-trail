"""Select inspected source frames for the bounded room; no new art synthesis."""
from pathlib import Path
import json,copy,hashlib
from PIL import Image
root=Path(__file__).resolve().parents[1]
kit=json.loads((root/'kits/manifest.json').read_text())
original=json.loads((root/'assets/sprites.json').read_text())
out={'schema_version':1,'status':'integrated_room_review','source_catalog':'kits/manifest.json','sprites':{},'scenery':[],'excluded':'Cattle graze/rest turns; Eleanor medical/camp bag changes; rustler reaction strips; unverified environment connections.'}
ground_path=root/'source/ground-v3.png'
if ground_path.exists():
    ground=Image.open(ground_path).convert('RGB')
    ground.resize((640,360),Image.Resampling.NEAREST).save(root/'assets/ground-v3.png')
    out['ground']={'texture':'res://assets/ground-v3.png','source':'source/ground-v3.png','sha256':hashlib.sha256(ground_path.read_bytes()).hexdigest(),'source_dimensions':list(ground.size),'output_dimensions':[640,360],'sampling':'nearest','provenance':'Quieter clustered empty-ground derivative generated from approved source/concept-start.jpg; prompt in source/ground-v3-prompt.txt'}
for name in ['rider','longhorn','cream','spotted','eleanor','rustler']:
    spec=copy.deepcopy(kit['families'][name]); spec['clips']={}
    source=kit['families'][name]['clips']
    directions=['east','west','north','south']
    if name in ['rider','longhorn','cream','spotted']: directions += [d for d in ['northeast','northwest','southeast','southwest'] if 'walk_'+d in source]
    for direction in directions:
        for action in ['idle','walk']:
            clip_name=action+'_'+direction
            source_name='v4_'+clip_name if 'v4_'+clip_name in source else clip_name
            spec['clips'][clip_name]=copy.deepcopy(source[source_name])
            if action=='idle': spec['clips'][action+'_'+direction]['fps']=3
    if name=='rider':
        alignment=json.loads((root/'assets/rider-anchors.json').read_text())
        spec['clip_anchors']={clip:data['anchor'] for clip,data in alignment['clips'].items()}
        for clip in spec['clips']:
            if 'v4_'+clip in alignment['clips']: spec['clip_anchors'][clip]=alignment['clips']['v4_'+clip]['anchor']
        spec['anchor_policy']=alignment['method']
        spec['action_events']={}
        for direction in directions:
            for action in ['lasso','shoot']:
                clip=copy.deepcopy(source[action+'_'+direction]);clip['loop']=False;clip['fps']=10 if action=='shoot' else 8
                spec['clips'][action+'_'+direction]=clip
                if action=='lasso' and direction in ['northwest','southeast']:
                    # Exclude the candidate's wrong-side extension; hold its correctly facing overhead loop.
                    f=clip['frames'];clip['frames']=[f[0],f[1],f[1],f[3]]
                spec['action_events'][action+'_'+direction]={'name':'fire' if action=='shoot' else 'rope_release','frame':(0 if direction=='north' else 1) if action=='shoot' else 2,'basis':'Visible muzzle flash for shoot; extended loop pose for lasso','once_per_action':True}
                if action=='lasso' and direction in ['northwest','southeast']:
                    spec['action_events'][action+'_'+direction]['basis']='Release during held overhead loop; wrong-side source extension excluded'
    if name=='eleanor':
        # Two standing hand gestures keep the bag out of the animation.
        spec['clips']['talk_east']={'frames':[4,5,4,5],'fps':3,'loop':False}
        spec['clips']['idle_east']={'frames':[4],'fps':1,'loop':True}
        if 'v5_walk_east' in source:
            spec['clips']['walk_east']={'frames':source['v5_walk_east']['frames'],'fps':6,'loop':True,'durations':[0.18,0.15,0.18,0.15]}
    if name=='rustler':
        reaction_path=root/'assets/curation/rustler-reaction.json'
        if reaction_path.exists():
            reaction=json.loads(reaction_path.read_text())
            spec['clips']['yield_southwest']={'frames':reaction['frames'],'fps':1,'loop':False,'durations':reaction['durations']}
        escape_path=root/'assets/curation/rustler-escape.json'
        if escape_path.exists():
            escape=json.loads(escape_path.read_text())
            spec['clips']['run_east']={'frames':escape['frames'],'fps':8,'loop':True,'durations':escape['durations']}
    if name=='rider' and 'v5_lasso_northeast' in source:
        sequence=json.loads((root/'assets/sequence-curation.json').read_text())
        spec['frame_sockets']={}
        for action in ['walk','lasso']:
            recipe=sequence[action]; frames=source[recipe['source_clip']]['frames']
            clip_name=action+'_northeast'
            spec['clips'][clip_name]={'frames':[frames[i] for i in recipe['order']],'fps':8,'loop':action=='walk','durations':recipe['durations']}
            spec['clip_anchors'][clip_name]=alignment['clips'][recipe['source_clip']]['anchor']
        lasso_frames=source[sequence['lasso']['source_clip']]['frames']
        for frame,point in zip(lasso_frames,sequence['lasso']['hand_sockets']): spec['frame_sockets'][str(frame)]={'rope_hand':point}
        for frame in source[sequence['walk']['source_clip']]['frames']: spec['frame_sockets'][str(frame)]={'rope_hand':[54,51]}
        spec['clips']['idle_northeast']={'frames':[lasso_frames[-1]],'fps':1,'loop':True}
        spec['clip_anchors']['idle_northeast']=spec['clip_anchors']['lasso_northeast']
        spec['action_events']['lasso_northeast']={'name':'rope_release','frame':sequence['lasso']['release_ordinal'],'basis':'Clean open-hand release; engine owns the single rope','once_per_action':True}
        spec['procedural_rope_clips']=['lasso_northeast']
        for direction in ['northwest','east','west','north','south','southeast','southwest']:
            source_name='v5_lasso_'+direction
            if source_name not in source: continue
            clip_name='lasso_'+direction; recipe=sequence[clip_name]; frames=source[source_name]['frames']
            spec['clips'][clip_name]={'frames':[frames[i] for i in recipe['order']],'fps':8,'loop':False,'durations':recipe['durations']}
            spec['clip_anchors'][clip_name]=alignment['clips'][source_name]['anchor']
            for frame,point in zip(frames,recipe['hand_sockets']): spec['frame_sockets'][str(frame)]={'rope_hand':point}
            walk_hands={'east':[54,51],'west':[40,51],'northwest':[40,51],'north':[54,53],'south':[40,51],'southeast':[40,52],'southwest':[43,52]}
            for frame in source['walk_'+direction]['frames']: spec['frame_sockets'][str(frame)]={'rope_hand':walk_hands[direction]}
            spec['clips']['idle_'+direction]={'frames':[frames[recipe['order'][-1]]],'fps':1,'loop':True}
            spec['clip_anchors']['idle_'+direction]=spec['clip_anchors'][clip_name]
            spec['action_events'][clip_name]={'name':'rope_release','frame':recipe['release_ordinal'],'basis':'Clean directional open-hand release; engine owns the single rope','once_per_action':True}
            spec['procedural_rope_clips'].append(clip_name)
        greeting_path=root/'assets/curation/rider-greeting.json'
        if greeting_path.exists():
            greeting=json.loads(greeting_path.read_text())
            spec['clips']['greeting_northwest']={'frames':greeting['frames'],'fps':greeting['fps'],'loop':False,'durations':greeting['durations']}
            spec['clip_anchors']['greeting_northwest']=greeting['anchor']
    if name in ['longhorn','cream','spotted']:
        necks={'east':[53,40],'west':[18,40],'north':[36,31],'south':[36,43],'northeast':[44,38],'northwest':[24,36],'southeast':[48,42],'southwest':[23,42]}
        spec['frame_sockets']={str(i):{'rope_neck':necks[frame['direction']]} for i,frame in enumerate(spec['frames']) if frame['direction'] in necks}
    spec['clips']['idle']=copy.deepcopy(spec['clips']['idle_east'])
    if 'idle_northeast' in spec['clips']:
        spec['default_facing']='northeast'
        spec['clips']['idle']=copy.deepcopy(spec['clips']['idle_northeast'])
        if name=='rider': spec['clip_anchors']['idle']=spec['clip_anchors']['idle_northeast']
    spec['status']='selected_for_room_review'
    spec['locomotion']={'nominal_speed':24 if name=='rider' else 36,'facing_bias':1.2,'phase_policy':'Preserve walk-cycle phase across facing changes','speed_scale_limits':[0.35,1.8],'idle_when_blocked':True}
    if name=='rider':
        spec['locomotion'].update(travel_speed=32,clip_nominal_speeds={'walk_northeast':24},stride_basis='NE: provisional12 pixels per0.5sec compact cycle from assets/curation/rider-walk.json; other facings provisional24px/sec nominal. Contact anatomy remains under review.')
    if name=='rustler': spec['locomotion'].update(escape_speed=48,clip_nominal_speeds={'run_east':48})
    if name=='rider':
        walk_paths=[root/'assets/curation/rider-next-walk.json',root/'assets/curation/rider-northwest-walk.json']
        for walk_path in walk_paths:
            if not walk_path.exists(): continue
            walk=json.loads(walk_path.read_text(encoding='utf-8'))
            clip_name=walk['target_clip']
            assert all(spec['frames'][i]['id']==fid for i,fid in zip(walk['frames'],walk['frame_ids']))
            spec['clips'][clip_name]={'frames':walk['frames'],'fps':walk['fps'],'loop':True,'durations':walk['durations']}
            spec['clip_anchors'][clip_name]=walk['anchor']
            spec['locomotion']['clip_nominal_speeds'][clip_name]=walk['nominal_speed']
            spec['frame_sockets'].update(walk.get('frame_sockets',{}))
        # Authored whole-rider 22.5-degree bridges; both turn directions use
        # the same intermediate heading, with a grounded or low-passing pose.
        bridges={
            'nnw':{'source':'turn_v1_turn_north-northwest','hands':[[40,46],[40,46]]},
            'nne':{'source':'turn_v1_turn_north-northeast','hands':[[54,45],[54,45]]},
        }
        spec['turn_transitions']={}
        for heading,bridge in bridges.items():
            if bridge['source'] not in source: continue
            indices=source[bridge['source']]['frames']
            assert len(indices)==2, f"Expected grounded/passing pair for {heading}"
            anchor=alignment['clips'][bridge['source']]['anchor']
            for ordinal,state in enumerate(['grounded','passing']):
                index=indices[ordinal]
                assert spec['frames'][index]['source']=='kits/source/rider-northern-turn-v1.png'
                clip_name=f'turn_{heading}_{state}'
                spec['clips'][clip_name]={'frames':[index],'fps':1,'loop':False}
                spec['clip_anchors'][clip_name]=anchor
                spec['frame_sockets'][str(index)]={'rope_hand':bridge['hands'][ordinal]}
            endpoints=['northwest','north'] if heading=='nnw' else ['north','northeast']
            for start,end in [endpoints,endpoints[::-1]]:
                modes={'idle':{'clip':f'turn_{heading}_grounded','seconds':0.08},
                       'walk':{'clip':f'turn_{heading}_passing','seconds':0.07}}
                assert all(len(spec['clips'][data['clip']]['frames'])==1 for data in modes.values())
                spec['turn_transitions'].setdefault(start,{})[end]=modes
    spec['selection_note']='Walk and stationary facing reviewed together; action strips selectively enabled. Final room acceptance is separate.'
    out['sprites'][name]=spec
out['sprites']['wagon']=copy.deepcopy(original['sprites']['wagon'])
def add(family,index,x,y,solid=0):
    spec=kit['families'][family]
    out['scenery'].append({'family':family,'frame':index,'texture':spec['texture'],'region':spec['frames'][index]['atlas_rect'],'anchor':spec['anchor'],'position':[x,y],'collision_radius':solid,'source_frame_id':spec['frames'][index]['id']})
for item in [(1,55,103),(20,280,108),(22,436,100),(2,586,104),(14,363,94)]:add('trees',*item,solid=9)
for item in [(16,32,276),(3,603,288),(9,437,302),(25,163,303),(1,360,103)]:add('rocks',*item,solid=6)
for item in [(0,50,323),(2,205,93),(4,464,303),(8,578,317),(12,322,315)]:add('scrub',*item)
for item in [(0,64,139),(4,51,119),(9,108,148),(7,125,139),(12,49,163)]:add('camp',*item)
for i,(x,y) in enumerate([(76,285),(123,304),(216,305),(255,318),(346,292),(398,313),(522,297),(565,277),(598,121),(410,96),(315,109),(169,97),(234,72),(462,91),(542,95),(37,205),(611,223),(90,185),(446,267),(194,278)]):
    add('grass',[0,1,3,4,5,8,9,10,12,13][i%10],x,y)
# Deterministic native-pixel groundcover selection from the rich Texas sheet.
from build_texas_scenery import build as build_texas_scenery
texas = build_texas_scenery()
out['scenery'].extend(texas['placements'])
out['texas_scenery_catalog'] = 'assets/texas-scenery.json'
out['integrated_unique_actor_frames']=sum(len({i for c in s['clips'].values() for i in c['frames']}) for s in out['sprites'].values())
out['integrated_unique_scenery_frames']=len({(s['family'],s['frame']) for s in out['scenery']})
(root/'assets/room-art.json').write_text(json.dumps(out,indent=2)+'\n')
print('Room selection:',out['integrated_unique_actor_frames'],'actor frames;',out['integrated_unique_scenery_frames'],'scenery variants;',len(out['scenery']),'placements')
