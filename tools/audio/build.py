## Rebuilds assets/audio from the downloaded CC0 packs (see fetch.sh).
##   python3 tools/audio/extras.py            # writes extras.json + ambience.json
##   python3 tools/audio/build.py tools/audio/overrides.json assets/audio/sfx
##   python3 tools/audio/build.py tools/audio/extras.json assets/audio/sfx
##   python3 tools/audio/build.py tools/audio/ambience.json assets/audio/ambience
## Each spec maps an id to layers: src (a unique path suffix inside $SND),
## start/dur (seconds), gain (dB), delay, pitch, hp/lp (Hz), fadein/fadeout.
## Needs ffmpeg, numpy and scipy.
import subprocess, numpy as np, json, os, sys
from scipy.signal import butter, sosfilt
SR = 44100
SND = os.environ.get('SND', '/tmp/snd')
def load(p, stereo=False, pitch=1.0):
    af = []
    if pitch != 1.0:
        af = ['-af', f'asetrate={int(SR*pitch)},aresample={SR}']
    ch = 2 if stereo else 1
    r = subprocess.run(['ffmpeg','-v','error','-i',p,*af,'-ac',str(ch),'-ar',str(SR),'-f','f32le','-'],capture_output=True)
    if r.returncode: raise SystemExit(f"load failed {p}: {r.stderr[:300]}")
    x = np.frombuffer(r.stdout,dtype=np.float32).copy()
    return x.reshape(-1,ch)
ALL=[os.path.relpath(os.path.join(d,f),SND) for top in ('oga','kenney') for d,_,fs in os.walk(os.path.join(SND,top))
     for f in fs if f.lower().endswith(('.wav','.ogg','.mp3','.flac')) and '__MACOSX' not in d]
def resolve(q):
    if os.path.exists(q): return q
    m=[a for a in ALL if a.endswith(q)] or [a for a in ALL if q in a]
    if len(m)!=1: raise SystemExit(f"resolve {q}: {m[:5]}")
    return os.path.join(SND, m[0])
def filt(x, kind, f, order=2):
    sos = butter(order, f, btype=kind, fs=SR, output='sos')
    return sosfilt(sos, x, axis=0)
def layer(L, stereo):
    src = resolve(L['src'])
    x = load(src, stereo, L.get('pitch',1.0))
    s = int(L.get('start',0)*SR/L.get('pitch',1.0))  # start is in source time
    d = L.get('dur')
    x = x[s: s+int(d*SR) if d else None]
    if 'hp' in L: x = filt(x,'highpass',L['hp'])
    if 'lp' in L: x = filt(x,'lowpass',L['lp'])
    fi = int(L.get('fadein',0.003)*SR); fo = int(L.get('fadeout',0.05)*SR)
    if fi: x[:fi] *= np.linspace(0,1,fi)[:,None]
    if fo and fo < len(x): x[-fo:] *= (np.linspace(1,0,fo)**2)[:,None]
    x = x*10**(L.get('gain',0)/20)
    pad = np.zeros((int(L.get('delay',0)*SR), x.shape[1]),dtype=np.float32)
    return np.vstack([pad,x])
def build(name, spec, outdir):
    stereo = spec.get('stereo',False)
    ls = [layer(L,stereo) for L in spec['layers']]
    n = max(len(l) for l in ls); y = np.zeros((n, ls[0].shape[1]))
    for l in ls: y[:len(l)] += l
    if spec.get('loop'):  # crossfade tail into head for a seamless loop
        cf = int(spec.get('xfade',1.0)*SR); head = y[:cf].copy(); y = y[cf:]
        y[-cf:] = y[-cf:]*np.linspace(1,0,cf)[:,None]**0.5 + head*np.linspace(0,1,cf)[:,None]**0.5
    pk = np.abs(y).max()+1e-9
    if not spec.get('loop'):  # drop leading silence so the sound lands on the frame it is played
        a = np.abs(y).max(axis=1); i = int(np.argmax(a > pk*0.02)); i = max(0, i-int(0.004*SR))
        y = y[i:]
        if i: y[:int(0.002*SR)] *= np.linspace(0,1,int(0.002*SR))[:,None]
        a = np.abs(y).max(axis=1); j = len(a)-int(np.argmax(a[::-1] > pk*0.003)); y = y[:max(j, int(0.05*SR))]
    if 'rms' in spec:
        y *= 10**(spec['rms']/20)/np.sqrt((y*y).mean()+1e-12)
        if np.abs(y).max()>0.97: y*=0.97/np.abs(y).max()
    else:
        y *= 10**(spec.get('norm',-1.5)/20)/pk
    os.makedirs(outdir, exist_ok=True)
    out = os.path.join(outdir, name+'.ogg')
    q = str(spec.get('q', 3))
    r = subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac',str(y.shape[1]),'-i','-','-c:a','libvorbis','-q:a',q,out],input=y.astype(np.float32).tobytes(),capture_output=True)
    if r.returncode: print(r.stderr)
    return out, len(y)/SR
if __name__=='__main__':
    specs = json.load(open(sys.argv[1]))
    outdir = sys.argv[2]
    only = sys.argv[3:]
    for k,v in specs.items():
        if only and k not in only: continue
        if k.startswith('_'): continue
        o,d = build(k, v, outdir)
        print(f"{k:30} {d:5.2f}s {os.path.getsize(o)//1024}KB")
