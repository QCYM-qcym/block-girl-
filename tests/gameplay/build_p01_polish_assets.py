"""Original deterministic TEMP sounds and repo-native pixel key icons; no downloads."""
from pathlib import Path
import json, math, wave
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'production/audio/p01'; OUT.mkdir(parents=True,exist_ok=True)
SR=44100
rng=np.random.default_rng(120926)
def tone(freq,length,decay=7):
    t=np.arange(round(length*SR))/SR
    return np.sin(2*np.pi*freq*t)*np.minimum(1,t/.008)*np.exp(-decay*t/length)*(1-t/length)
def cue(freqs,length,noise=0):
    a=sum(tone(f,length,5+i) /(i+1) for i,f in enumerate(freqs))
    if noise:
        n=rng.normal(size=len(a)); n=np.convolve(n,np.ones(22)/22,mode='same')
        t=np.arange(len(a))/SR; a+=n*noise*np.sin(np.pi*t/length)**2*np.exp(-8*t/length)
    a*=np.minimum(1,np.arange(len(a))/220)*np.minimum(1,np.arange(len(a))[::-1]/330)
    return a/(max(abs(a))+1e-9)*.35
specs={
 'roll':([145,217,290],.15,.6,'PLAYER'), 'land':([100,150],.10,.3,'PLAYER'),
 'shift_inner':([220,330,440],.40,.04,'WORLD'), 'shift_surface':([330,495,660],.40,.03,'WORLD'),
 'rotate':([280,420],.18,.05,'WORLD'), 'link_on':([440,660],.24,0,'WORLD'),
 'link_off':([330,220],.16,0,'WORLD'), 'plate':([180,270],.13,.35,'MECHANISM'),
 'door_open':([155,233,310],.28,.25,'MECHANISM'), 'door_close':([125,188],.24,.3,'MECHANISM'),
 'exit_ready':([392,588],.34,0,'MECHANISM'), 'complete':([330,440,660],1.2,0,'UI')}
manifest={}
def save(name,a,category,loop=False):
    if a.ndim==1: a=np.column_stack([a,a])
    assert np.max(abs(a))<.8 and np.all(np.isfinite(a))
    path=OUT/f'TEMP_{name}.wav'
    with wave.open(str(path),'wb') as wav:
        wav.setnchannels(2); wav.setsampwidth(2); wav.setframerate(SR)
        wav.writeframes(np.rint(a*32767).astype('<i2').tobytes())
    manifest[name]={'path':f'res://production/audio/p01/{path.name}','category':category,'duration':len(a)/SR,
        'peak':float(abs(a).max()),'rms':float(np.sqrt(np.mean(a*a))),'loop':loop,
        'status':'TEMPORARY','source':'Generated in-project / Original','author':'Project procedural recipe (Codex-assisted)',
        'license':'CC0-1.0','redistribution':True}
for name,(freqs,length,noise,category) in specs.items():
    a=cue(freqs,length,noise)
    if name=='shift_inner': a=a[::-1].copy()*.7
    if name=='link_off': a*=.45
    if name=='land': a*=.5
    if name=='complete':
        a=cue([330,660],1.2)
        for offset,f in [(0.16,440),(0.34,660)]:
            n=tone(f,1.2-offset,4); start=round(offset*SR); a[start:start+len(n)]+=n*.07
        a*=.35/max(abs(a))
    save(name,a,category)
for name,cut,base in [('amb_surface',1100,165),('amb_inner',650,110)]:
    count=SR*8; freqs=np.fft.rfftfreq(count,1/SR)
    spectrum=rng.normal(size=len(freqs))+1j*rng.normal(size=len(freqs))
    spectrum*=np.exp(-freqs/cut)*np.minimum(freqs/80,1)
    a=np.fft.irfft(spectrum,n=count); a/=max(abs(a))
    t=np.arange(count)/SR
    a=a*.025+np.sin(2*np.pi*base*t)*.006+np.sin(2*np.pi*base*1.5*t)*.003
    stereo=np.column_stack([a,np.roll(a,137)])
    save(name,stereo,'AMBIENCE',True)
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')

# Small UI shapes are deliberately code-native icons, with sharp integer pixel glyphs.
glyphs={'W':['10101','10101','10101','10101','01110'],'A':['01110','10001','11111','10001','10001'],
 'S':['01111','10000','01110','00001','11110'],'D':['11110','10001','10001','10001','11110'],
 'Q':['01110','10001','10101','10010','01101'],'E':['11111','10000','11110','10000','11111']}
im=Image.new('RGBA',(128,32)); draw=ImageDraw.Draw(im)
for i,k in enumerate('WASDQE'):
    x=i*16; draw.rectangle((x,0,x+13,13),outline='#9bada4',fill='#273a3b')
    for y,row in enumerate(glyphs[k]):
        for j,on in enumerate(row):
            if on=='1': draw.point((x+4+j,4+y),fill='#d7e3d8')
draw.rectangle((0,16,43,29),outline='#9bada4',fill='#273a3b')
draw.line((7,23,7,25,36,25,36,23),fill='#d7e3d8',width=1)
draw.rectangle((49,17,58,29),outline='#9bada4'); draw.line((49,21,58,21),fill='#9bada4'); draw.line((54,17,54,21),fill='#d7e3d8')
draw.line((64,23,82,23),fill='#9bada4'); draw.line((67,20,64,23,67,26),fill='#9bada4'); draw.line((79,20,82,23,79,26),fill='#9bada4')
ui=ROOT/'production/ui/p01'; ui.mkdir(parents=True,exist_ok=True); im.save(ui/'tutorial_keys.png')
assert set(im.getchannel('A').tobytes())=={0,255}
doc=ROOT/'docs/audio'; doc.mkdir(parents=True,exist_ok=True)
lines=['# AUDIO_ASSET_MANIFEST','','All assets: Generated in-project / Original; TEMPORARY foundation sounds.',
 'Author: project procedural recipe, Codex-assisted. License: CC0-1.0 (project grants unrestricted reuse/redistribution of these original generated files). No external recordings, samples or copyrighted music were used.',
 'No third-party license dependency. Recipe: tests/gameplay/build_p01_polish_assets.py; deterministic seed120926.','',
 '| asset | use/category | source | author | license | redistributable | path | duration | status |','|---|---|---|---|---|---|---|---|---|']
for name,r in manifest.items():
    lines.append(f'| {name} | {r["category"]} | Generated in-project / Original | Project procedural recipe | CC0-1.0 | YES | {r["path"]} | {r["duration"]:.2f}s | TEMPORARY |')
lines+=['','Stereo PCM16 / 44.1kHz. Every SFX has an explicit attack/release; roll0.15s and land0.10s are shorter than the0.32s movement cycle. Ambience uses periodic Fourier noise and harmonic periods over8s, with wrapped stereo offset. Runtime gain and buses provide additional headroom. These are temporary authored sound-design building blocks, not licensed commercial Foley or final BGM.']
(doc/'AUDIO_ASSET_MANIFEST.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('POLISH ASSETS: 12 SFX + 2 periodic ambiences + binary-alpha key icons; PASS')
