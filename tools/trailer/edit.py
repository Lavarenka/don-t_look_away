# Монтаж трейлера: планы из записей Movie Maker + титры + музыка → trailer.mp4 (1920x1080, 30 fps).
# На ПК (один прогон всего трейлера):  python3 tools/trailer/edit.py trailer trailer/trailer.mp4 trailer/raw_shots.txt
# Проба (каждый план отдельно):       python3 edit.py <папка с mov/sN.avi и shot_N.txt> <выход.mp4>
import subprocess, sys, os, json
SRC, OUT = sys.argv[1], sys.argv[2]
ONE_LOG = sys.argv[3] if len(sys.argv) > 3 else ""
HERE = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1920, 1080, 30
subprocess.run(["python3", os.path.join(HERE, "cards.py"), str(W), str(H)], check=True)

ORDER = ["hall", "tv", "corridor", "girl_far", "attic", "bath", "bed_door", "bed", "scare"]
# таймлайн: (тип, имя/картинка, длительность титра)
TIMELINE = [("card", "c1.png", 3.2), ("shot", "hall"), ("shot", "tv"), ("card", "c2.png", 2.9),
            ("shot", "corridor"), ("shot", "girl_far"), ("shot", "attic"), ("card", "c3.png", 2.5),
            ("shot", "bath"), ("shot", "bed_door"), ("shot", "bed"), ("card", "c4.png", 1.6),
            ("shot", "scare"), ("black", None, 0.5), ("card", "title.png", 5.5)]

# где лежит каждый план: (файл, начало, конец)
spans = {}
if ONE_LOG:      # один прогон всего трейлера (так будет на ПК): raw.avi + raw_shots.txt
    for line in open(ONE_LOG):
        p = line.split()
        if len(p) == 3:
            spans[p[0]] = (os.path.join(SRC, "raw.avi"), float(p[1]), float(p[2]))
else:            # проба: каждый план записан отдельно
    for i, nm in enumerate(ORDER):
        log = os.path.join(SRC, f"shot_{i}.txt")
        p = open(log).read().split()
        spans[nm] = (os.path.join(SRC, "mov", f"s{i}.avi"), float(p[1]), float(p[2]))

inputs, filters, vlabels, alabels = [], [], [], []
t = 0.0
marks = {}
for k, item in enumerate(TIMELINE):
    kind = item[0]
    idx = sum(1 for x in inputs if x == "-i")
    if kind == "shot":
        f, a, b = spans[item[1]]
        d = b - a
        inputs += ["-i", f]
        fi = 0.12
        filters.append(f"[{idx}:v]trim={a:.3f}:{b:.3f},setpts=PTS-STARTPTS,scale={W}:{H},fps={FPS},format=yuv420p,"
                       f"fade=t=in:st=0:d={fi},fade=t=out:st={d - fi:.3f}:d={fi}[v{k}]")
        filters.append(f"[{idx}:a]atrim={a:.3f}:{b:.3f},asetpts=PTS-STARTPTS,aresample=48000,aformat=channel_layouts=stereo,"
                       f"afade=t=in:st=0:d=0.05,afade=t=out:st={d - 0.08:.3f}:d=0.08,volume=0.9[a{k}]")
    else:
        d = item[2]
        img = os.path.join(HERE, item[1]) if item[1] else None
        if img:
            inputs += ["-loop", "1", "-t", f"{d}", "-i", img]
            fd = 0.6 if item[1] != "c4.png" else 0.3
            filters.append(f"[{idx}:v]scale={W}:{H},fps={FPS},format=yuv420p,fade=t=in:st=0:d={fd},fade=t=out:st={d - fd:.3f}:d={fd}[v{k}]")
        else:
            inputs += ["-f", "lavfi", "-t", f"{d}", "-i", f"color=c=black:s={W}x{H}:r={FPS}"]
            filters.append(f"[{idx}:v]format=yuv420p[v{k}]")
        filters.append(f"anullsrc=r=48000:cl=stereo,atrim=0:{d}[a{k}]")
    marks[item[1] or "black"] = t
    t += d
    vlabels.append(f"[v{k}]")
    alabels.append(f"[a{k}]")
total = t
n = len(TIMELINE)
filters.append("".join(v + a for v, a in zip(vlabels, alabels)) + f"concat=n={n}:v=1:a=1[vc][ac]")
# музыка под всё: удары и тишина привязаны к таймлайну
scare_at = marks["scare"] + 1.25
title_at = marks["title.png"]
subprocess.run(["python3", os.path.join(HERE, "music.py"), f"{total:.3f}", f"{scare_at:.3f}", f"{title_at:.3f}"], cwd=HERE, check=True)
inputs += ["-i", os.path.join(HERE, "music.wav")]
mi = len([x for x in inputs if x == "-i"]) - 1
filters.append(f"[{mi}:a]volume=0.75[mus];[ac][mus]amix=inputs=2:duration=longest:normalize=0,alimiter=limit=0.95[aout]")
cmd = ["ffmpeg", "-y", "-loglevel", "error"] + inputs + ["-filter_complex", ";".join(filters), "-map", "[vc]", "-map", "[aout]",
       "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "256k",
       "-movflags", "+faststart", OUT]
subprocess.run(cmd, check=True)
print(json.dumps({"total": round(total, 2), "scare": round(scare_at, 2), "title": round(title_at, 2)}))
