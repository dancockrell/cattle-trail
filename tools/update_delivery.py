from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
path=root/'kits/catalog-plan.json'
plan=json.loads(path.read_text()); manifest=json.loads((root/'kits/manifest.json').read_text())
plan['targets'].update(actor_frames=400,total_minimum=496,actor_expansion_over_baseline=400/24)
plan['directions']=['east','west','north','south']
plan['revision_note']='First extraction allocates four 4-frame action rows per requested facing; Eleanor expanded to four facings. Direction labels are requests, not verified coverage. Connectivity remains an admission requirement.'
actions={'rider':['walk','trot','lasso','shoot'],'longhorn':['walk','run','graze','rest'],'cream':['walk','run','graze','rest'],'spotted':['walk','run','graze','rest'],'eleanor':['walk','talk','medical','camp'],'rustler':['walk','run','shoot','react']}
for family in plan['families']:
    name=family['id']
    if name in actions:
        family['target_unique_usable_frames_or_modules']=64
        family['coverage']={'directions':plan['directions'],'clips':{a:{'frames_per_direction':4} for a in actions[name]},'idle':'Reuse first walk frame without counting it again.'}
    family['measured_inventory']='manifest.json#families/'+name
plan['admission_policy']['future_delivery_inventory']='manifest.json records actual extraction; DELIVERY.md records admission and integration boundaries.'
path.write_text(json.dumps(plan,indent=2)+'\n')
p=root/'kits/PLAN.md';t=p.read_text(encoding='utf-8')
t=t.replace('384 useful frames/states, exactly sixteen times','400 candidate frames/states, approximately 16.7 times').replace('384','400').replace('exactly sixteen','approximately 16.7').replace('**16× the 24-frame aggregate baseline**','**16.7× the 24-frame aggregate baseline**')
t=t.replace('Directions below are northeast, southeast, southwest, and northwest. These are planned production directions, not a claim about the original sheets.','Requested directions are east, west, north, and south within the high three-quarter presentation. Actual frame facing must be inspected; requests are not verified coverage. The first extraction uses four poses per action row and reuses the first walk pose for idle.')
t=t.replace('Per direction: idle 2, ride 6, lasso 4, shoot 4','Per direction: walk 4, trot 4, lasso 4, shoot 4').replace('Per direction: idle 2, walk 4, run 4, graze 3, startle 3','Per direction: walk 4, run 4, graze 4, rest 4').replace('| Eleanor | 48 | Per direction: idle 2, walk 4, talk 3, gesture 3 |','| Eleanor | 64 | Per direction: walk 4, talk 4, medical 4, camp 4 |').replace('Per direction: idle 2, walk 4, shoot 4, flee 4, lasso reaction 2','Per direction: walk 4, run 4, shoot 4, react 4')
t += '\n## First extraction status\n\n496 unique cells extracted: 400 actors/props plus 96 scenery variants. See DELIVERY.md for measured results. Connected grass/fence systems, approved gait cycles, and interaction footprints remain unfulfilled admission requirements. Generated decorative variety does not complete these requirements. Tree layers are exact complementary splits; they do not invent hidden trunk pixels and do not count as extra variants.\n'
p.write_text(t,encoding='utf-8')
p=root/'kits/README.md';t=p.read_text(encoding='utf-8').replace('A tree kit should later expose canopy/trunk layering where gameplay needs it;','The tree kit includes complementary canopy/trunk layers with shared anchors (their union reproduces the original silhouette);')
p.write_text(t,encoding='utf-8')
