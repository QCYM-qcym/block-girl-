"""Independent artifact contract: exact pixels and lookup edges, no gameplay reimplementation."""
import json, sys
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[2]
assets=root/'production/sprites/v2_orientation'
manifest=assets/'shared/orientation_sprite_manifest.json'
assert manifest.exists(), 'Formal orientation sprite manifest missing'
m=json.loads(manifest.read_text(encoding='utf-8-sig'))
assert len(m['poses'])==24
checks=0
def check(ok, message):
    global checks
    checks+=1
    assert ok, message
skins=[]
for skin in ['mutsumi','mortis']:
    atlas=Image.open(assets/skin/'orientation_atlas.png').convert('RGBA')
    frames=[atlas.crop((r[0],r[1],r[0]+24,r[1]+24)) for r in m['regions']]
    check(len({frames[i].tobytes() for i in m['stable']})==13, skin+' thirteen stable appearances')
    check(set(atlas.getchannel('A').tobytes())=={0,255},skin+' binary alpha')
    for i,im in enumerate(frames):
        b=im.getbbox()
        check(b is not None and b[0]>0 and b[1]>0 and b[2]<24 and b[3]==21,'canvas margin/baseline '+str(i))
    check(frames[m['stable'][0]].getbbox()==(4,5,20,21),'old formal 16x16 footprint preserved')
    skins.append(frames)
check(len(skins[0])==len(skins[1]),'same frame count')
for a,b in zip(*skins): check(a.getchannel('A').tobytes()==b.getchannel('A').tobytes(),'paired alpha')
for p,pose in enumerate(m['poses']):
    check(m['stable_face_pixels'][p]>0 if pose['columns'][2] in [[1,0,0],[0,1,0],[0,0,1]] else m['stable_face_pixels'][p]==0,'physical face hidden or visible')
    if m['stage']=='complete':
        for d in range(4):
            row=m['roll'][p][d]
            check(len(row)==5,'three intermediate samples')
            check(row[0]==m['stable'][p] and row[-1]==m['stable'][pose['next'][d]],'roll exact endpoints')
        for sign in range(2):
            row=m['camera'][p][sign]
            check(row[0]==m['stable'][p],'camera exact start')
            check(row[-1]==m['stable'][m['views'][3 if sign==0 else 1][p]],'camera exact end')
for view in m['views']:
    check(sorted(view)==list(range(24)),'camera permutation')
print(f'ORIENTATION SPRITE ASSETS: {checks} checks PASS; stage={m["stage"]}; frames={len(m["regions"])} per skin')
if m['stage']=='stable':
    (assets/'shared/stable_validation_pass.json').write_text(json.dumps({'checks':checks,'stable_per_skin':13,'status':'PASS'}))
