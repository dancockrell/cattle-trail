"""Package exact whole frames; never synthesize intermediate or repeated poses."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.parent / 'sheet04'
source_meta = json.loads((SOURCE / 'metadata.json').read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
definitions = {
    'idle': {
        'source_indices': list(range(8)),
        'durations': [.28, .18, .18, .24, .18, .18, .18, .28],
        'phases': ['settled gaze', 'downward glance', 'eyes closed/head rising', 'upward glance', 'return gaze', 'settled shoulders', 'small downward glance', 'return neutral'],
        'review': 'Readable head-look-and-return gesture, not a physically proven breathing cycle. Frames 7 and 0 both face forward with arms lowered; the seam is close in pose but braid, face and boot contours change. No repeated frame is inserted to hide that change.',
        'limitations': ['Independent drawings change face, boot silhouette and small body proportions.', 'Foot placement varies by a few source pixels despite the common extraction pivot.', 'Eight distinct poses do not prove fluid motion.'],
    },
    'talk': {
        'source_indices': list(range(16,24)),
        'durations': [.24, .24, .22, .24, .28, .24, .22, .28],
        'phases': ['neutral', 'open palm', 'point', 'chuckle', 'both hands open', 'hand to chest', 'lowering open palm', 'settled neutral'],
        'review': 'A complete stylized conversation gesture returns to neutral. Frames 23 and 16 both have arms down and a similar stance, so the semantic seam closes. The face and left boot contours pop at the seam. Large hand travel between gestures has no intermediate drawings; it is a stepped expressive loop, not smooth motion.',
        'limitations': ['Hand trajectories jump between gestures.', 'Mouth shape and face detail vary.', 'The chuckle pose changes torso width slightly.'],
    },
}
atlas = Image.new('RGBA', (2048,512))
frames = []
clips = {}
for row, (name, definition) in enumerate(definitions.items()):
    images = []
    indices = []
    for col, (source_index, phase) in enumerate(zip(definition['source_indices'],definition['phases'])):
        path = SOURCE / f'{source_index:02d}-whole-frame.png'
        im = Image.open(path).convert('RGBA')
        assert im.size == (256,256)
        pixels = hashlib.sha256(im.tobytes()).hexdigest()
        assert pixels == source_meta['frames'][source_index]['rgba_sha256']
        index = len(frames)
        indices.append(index)
        atlas.alpha_composite(im, (col*256,row*256))
        frames.append({'index': index, 'atlas_rect':[col*256,row*256,256,256], 'source_index':source_index, 'source_file':f'../sheet04/{path.name}', 'source_png_sha256':sha(path), 'rgba_sha256':pixels, 'anchor':[128,244], 'phase':phase})
        images.append(im)
    assert len({hashlib.sha256(im.tobytes()).hexdigest() for im in images}) == 8
    images[0].save(ROOT / f'{name}-review.png', save_all=True, append_images=images[1:], duration=[round(t*1000) for t in definition['durations']], loop=0, disposal=0, blend=0)
    decoded = Image.open(ROOT / f'{name}-review.png')
    assert decoded.n_frames == 8
    for i, original in enumerate(images):
        decoded.seek(i)
        assert decoded.convert('RGBA').tobytes() == original.tobytes()
    seam = Image.new('RGBA',(768,256))
    for col, im in enumerate([images[-2], images[-1], images[0]]):
        seam.alpha_composite(im,(col*256,0))
    seam.save(ROOT / f'{name}-seam.png')
    clips[name] = {'frames':indices, 'durations':definition['durations'], 'fps':8, 'loop':True, 'review_status':'sheet_review_candidate', 'loop_seam':definition['review'], 'limitations':definition['limitations']}
atlas.save(ROOT / 'atlas.png')
spec = {'id':'ada-role-loop-candidates-v1','character':'ada_mercer','age':22,'runtime_admitted':False,'status':'two_complete_review_loops_with_visible_continuity_limitations','texture':'res://kits/big-sheets/ada-v1/selected-loops/atlas.png','texture_sha256':sha(ROOT/'atlas.png'),'cell':[256,256],'anchor':[128,244],'pixels_per_world_unit':4,'default_facing':'southeast','directional':False,'source_sheet':'../sheet04/source.png','source_sheet_sha256':sha(SOURCE/'source.png'),'source_metadata_sha256':sha(SOURCE/'metadata.json'),'frames':frames,'clips':clips,'excluded_rows':{'repair':'Raised wrench reads as a strike rather than sustained wrench turning; missing coherent contact surface and return trajectory.','camp':'Mug appears duplicated during sipping and disappears during later gestures; continuity is not suitable for a care loop.'},'production_method':'Exact chronological whole-frame selection. No duplicated padding, interpolation, mirroring, redraw or rescaling. Timing is editorial and is not recovered motion capture.'}
(ROOT/'actor-spec.json').write_text(json.dumps(spec,indent=2)+'\n')
print('Packaged 16 distinct exact source frames in two 8-frame candidate loops. APNG pixel round-trip verified. Visual acceptance remains open.')
