"""Offline pixel cleanup and 2D face projection; consumes exported Godot poses.

No gameplay orientation implementation. Source imagegen drafts are normalized here;
only baked PNGs and a lookup JSON are needed at runtime.
"""
import argparse, hashlib, json, math, shutil
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'production/sprites/v2_orientation'
SOURCE=Path('E:/Study/方块娘项目/若叶睦/photo/production/sprites/v2_orientation')
GEN=Path('C:/Users/QCYM/.codex/generated_images/01a093f5-e0d8-7a30-b873-51b29c80046c')
DRAFTS=['exec-ed580c6a-bae9-40ee-8d2c-9a3a197cc87b.png','exec-b2681246-7867-43d3-8992-1f6b2dc0a587.png']
SKINS=['mutsumi','mortis']
PALETTES=[['a8b6a1','70867a','d1d9c8','e2e5d6','bfcbb9','344b45','9d9466','929d8e'],
          ['bcc7c6','7d9091','dde3df','e5e7e0','cad3cf','344450','938799','9ea8ac']]
DATA=json.loads((ROOT/'tests/gameplay/evidence/sprite_rework/orientations.json').read_text())
NORMALS=np.array([[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]],float)
NAMES=['FACE_RIGHT','FACE_LEFT','FACE_TOP','FACE_BOTTOM','FACE_FRONT','FACE_BACK']
CAM=np.array([1,.8,1])
P=np.array([[8,0,-8],[32/9,-80/9,32/9]])
yy,xx=np.mgrid[0:24,0:24]
PIXELS=np.stack([xx+.5,yy+.5],-1)

def rotation(axis,angle):
    # Presentation transform only (Rodrigues); discrete targets come from Godot.
    x,y,z=axis; c=math.cos(angle); s=math.sin(angle)
    k=np.array([[0,-z,y],[z,0,-x],[-y,x,0]])
    return np.eye(3)*c+(1-c)*np.outer(axis,axis)+s*k

def normalize():
    textures=[]; palettes=[]
    for skin,pal,draft in zip(SKINS,PALETTES,DRAFTS):
        path=OUT/skin; path.mkdir(parents=True,exist_ok=True)
        rgb=np.array([tuple(bytes.fromhex(c)) for c in pal],dtype=np.int32)
        raw=Image.open(GEN/draft).convert('RGB').resize((16,16),Image.Resampling.BOX)
        src=np.asarray(raw,dtype=np.int32)
        nearest=((src[:,:,None,:]-rgb[None,None,:,:])**2).sum(-1).argmin(-1)
        tex=rgb[nearest].astype(np.uint8)
        # Fixed grid cleanup: isolate two quiet eyes, mouth and a small Mortis accent.
        # Same grid in both skins; no geometry/pivot changes and no extruded details.
        tex[10,4:6]=rgb[5]; tex[10,10:12]=rgb[5]
        tex[11,5]=rgb[6] if skin=='mutsumi' else rgb[5]
        tex[11,10]=rgb[6] if skin=='mutsumi' else rgb[5]
        tex[14,7:9]=rgb[7]
        if skin=='mortis': tex[12,11]=rgb[6]
        Image.fromarray(tex).convert('RGBA').save(path/'face_front.png')
        Image.new('RGBA',(16,16),tuple(rgb[0])+(255,)).save(path/'face_unmarked.png')
        textures.append(tex); palettes.append(rgb)
    return textures,palettes

TEXTURES=[]; COLORS=[]
def bake(basis):
    corners=np.array([[x,y,z] for x in [-.5,.5] for y in [-.5,.5] for z in [-.5,.5]])
    projected=corners@basis.T@P.T
    offset=np.array([12.,21.-projected[:,1].max()])
    pair=[np.zeros((24,24,4),dtype=np.uint8) for _ in SKINS]
    face_mask=np.zeros((24,24),dtype=np.uint8)
    for index,n in enumerate(NORMALS):
        normal=basis@n
        if normal@CAM<=1e-7: continue
        u=np.array([1.,0,0]) if abs(n[1])>.5 else np.cross([0,1,0],n)
        v=np.cross(n,u)
        origin=P@(basis@((n-u-v)*.5))+offset
        transform=np.column_stack([P@basis@u,P@basis@v])
        uv=(PIXELS-origin)@np.linalg.inv(transform).T
        mask=(uv[:,:,0]>=0)&(uv[:,:,0]<1)&(uv[:,:,1]>=0)&(uv[:,:,1]<1)
        # Pixel-centre sampling, binary coverage: no supersampling or antialiasing.
        uv_index=np.clip((uv*16).astype(int),0,15)
        outline=((uv[:,:,0]<.065)|(uv[:,:,0]>.935)|(uv[:,:,1]<.065)|(uv[:,:,1]>.935))&mask
        shade=1.0 if normal[1]>.5 else (.80 if normal[2]>=normal[0] else .65)
        for w in range(2):
            color=TEXTURES[w][15-uv_index[:,:,1],uv_index[:,:,0]] if index==4 else np.broadcast_to(COLORS[w][0],(24,24,3))
            shaded=np.rint(color*shade).astype(np.uint8)
            pair[w][mask,:3]=shaded[mask]; pair[w][mask,3]=255
            pair[w][outline,:3]=COLORS[w][5]
        if index==4: face_mask[mask&~outline]=255
    return [Image.fromarray(p) for p in pair],Image.fromarray(face_mask)

def run(complete=False):
    global TEXTURES,COLORS
    for folder in ['shared','preview','spec']: (OUT/folder).mkdir(parents=True,exist_ok=True)
    TEXTURES,COLORS=normalize()
    frames=[]; masks=[]; hashed={}
    def register(b):
        pair,mask=bake(b)
        key=hashlib.sha256(b''.join(im.tobytes() for im in pair)+mask.tobytes()).hexdigest()
        if key not in hashed:
            hashed[key]=len(frames); frames.append(pair); masks.append(mask)
        return hashed[key]
    bases=[np.array(p['columns'],float).T for p in DATA['poses']]
    stable=[register(b) for b in bases]
    result={**DATA,'stage':'complete' if complete else 'stable','frame_size':[24,24],'pivot':[12,21],
            'stable':stable,'stable_face_pixels':[int(np.count_nonzero(masks[i])) for i in stable],
            'status':'AWAITING_GODOT_RUNTIME','roll':[],'camera':[]}
    # Production order is deliberately gated: first run stable, validate, then --transitions.
    if complete:
        proof=OUT/'shared/stable_validation_pass.json'
        assert proof.exists(),'Stable mapping must pass before transition production'
        axes=[[-1,0,0],[0,0,-1],[1,0,0],[0,0,1]]
        for p,b in enumerate(bases):
            rolls=[]; cameras=[]
            for d,axis in enumerate(axes):
                rolls.append([stable[p]]+[register(rotation(axis,j*math.pi/8)@b) for j in range(1,4)]+[stable[DATA['poses'][p]['next'][d]]])
            for sign in [-1,1]:
                cameras.append([stable[p]]+[register(rotation([0,1,0],sign*j*math.pi/16)@b) for j in range(1,8)]+[stable[DATA['views'][sign%4][p]]])
            result['roll'].append(rolls); result['camera'].append(cameras)
    cols=16; rows=math.ceil(len(frames)/cols)
    result['regions']=[[i%cols*24,i//cols*24,24,24] for i in range(len(frames))]
    result['face_pixels']=[int(np.count_nonzero(mask)) for mask in masks]
    for w,skin in enumerate(SKINS):
        atlas=Image.new('RGBA',(cols*24,rows*24))
        for i,pair in enumerate(frames): atlas.paste(pair[w],tuple(result['regions'][i][:2]))
        atlas.save(OUT/skin/'orientation_atlas.png')
        rgba=atlas.tobytes()
        result.setdefault('palette_rgb',{})[skin]=sorted({tuple(rgba[i:i+3]) for i in range(0,len(rgba),4) if rgba[i+3]})
    mask_atlas=Image.new('L',(cols*24,rows*24))
    for i,im in enumerate(masks): mask_atlas.paste(im,tuple(result['regions'][i][:2]))
    mask_atlas.save(OUT/'shared/character_face_mask.png')
    result['unique_stable_per_skin']=[len({frames[i][w].tobytes() for i in stable}) for w in range(2)]
    result['physical_faces']={name:normal.astype(int).tolist() for name,normal in zip(NAMES,NORMALS)}
    result['character_face']='FACE_FRONT'
    (OUT/'shared/orientation_sprite_manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    # View-only contact: every logical orientation, labels kept out of production PNG.
    preview=Image.new('RGB',(24*8*8,24*8*6+80),'#19272b'); draw=ImageDraw.Draw(preview)
    for w,skin in enumerate(SKINS):
        for p,idx in enumerate(stable):
            x=p%8*192; y=(p//8+w*3)*192+40
            preview.paste(frames[idx][w].resize((192,192),Image.Resampling.NEAREST),(x,y),frames[idx][w].resize((192,192),Image.Resampling.NEAREST))
            draw.text((x+6,y+5),f'{skin} O{p:02d}',fill='#ced8d3')
    preview.save(OUT/'preview/stable_orientations.png')
    if complete:
        cycle=[]; pose=0
        for step in range(4):
            cycle.extend(result['roll'][pose][0][:-1])
            pose=DATA['poses'][pose]['next'][0]
        cycle.append(stable[pose])
        animation=[]
        for idx in cycle:
            page=Image.new('RGB',(480,270),'#172327'); pen=ImageDraw.Draw(page)
            for w,skin in enumerate(SKINS):
                enlarged=frames[idx][w].resize((240,240),Image.Resampling.NEAREST)
                page.paste(enlarged,(w*240,20),enlarged); pen.text((w*240+65,8),skin,fill='#d1d9d2')
            animation.append(page)
        durations=[650 if i%4==0 else 100 for i in range(len(cycle))]
        animation[0].save(OUT/'preview/north_roll_cycle.gif',save_all=True,append_images=animation[1:],duration=durations,loop=0)
    lines=['# Orientation Sprite Manifest','',f'Stage: {result["stage"]}; status: {result["status"]}.',
           f'24 logical orientations -> {result["unique_stable_per_skin"]} unique stable appearances (per skin).',
           f'{len(frames)} unique paired frames including transitions. Frame 24x24, pivot (12,21).',
           'Only FACE_FRONT / local +Z carries the character face. Other five faces share unmarked material.',
           'Full roll_transition_to and lookup arrays are in shared/orientation_sprite_manifest.json.','',
           '| orientation_id | physical_face_mapping (R,U,F) | perspective | sprite_region | frame_size | pivot | character_face_visible | roll_transition_to | world_skin | status |',
           '|---|---|---|---|---|---|---|---|---|---|']
    for p,pose in enumerate(DATA['poses']):
        for v,view in enumerate(['NORTH','EAST','SOUTH','WEST']):
            canonical=DATA['views'][v][p]; idx=stable[canonical]
            for skin in SKINS:
                lines.append(f'| O{p:02d} | {pose["columns"]} | {view} | {result["regions"][idx]} | 24x24 | 12,21 | {result["face_pixels"][idx]>0} | {pose["next"]} | {skin} | AWAITING_GODOT_RUNTIME |')
    (OUT/'orientation_sprite_manifest.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    shutil.copy2(ROOT/'docs/design/CUBE_SPRITE_PRESENTATION_SPEC.md',OUT/'spec/CUBE_SPRITE_PRESENTATION_SPEC.md')
    for skin,draft in zip(SKINS,DRAFTS):
        d=SOURCE/'preview/imagegen_drafts'; d.mkdir(parents=True,exist_ok=True)
        shutil.copy2(GEN/draft,d/(skin+'_front_draft.png'))
    shutil.copytree(OUT,SOURCE,dirs_exist_ok=True)
    print(json.dumps({'stage':result['stage'],'stable':result['unique_stable_per_skin'],'frames':len(frames)}))

if __name__=='__main__':
    args=argparse.ArgumentParser(); args.add_argument('--transitions',action='store_true')
    run(args.parse_args().transitions)
