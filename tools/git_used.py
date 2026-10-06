#!/usr/bin/env python3
"""Находит файлы, которые реально использует игра, и пишет .gitignore-«белый список».
Запуск из корня проекта:  python3 tools/git_used.py
Всё, что не нашлось (неиспользуемые модели, звуки, текстуры), в git не попадает."""
import os, re, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
ALL = []
for d, dirs, fs in os.walk('.'):
    dirs[:] = [x for x in dirs if x not in ('.godot', '.git')]
    for f in fs:
        ALL.append(os.path.normpath(os.path.join(d, f)).replace('\\', '/'))
ALLSET = set(ALL)
TEXT = ('.tscn', '.tres', '.gd', '.godot', '.gdshader', '.gltf', '.cfg', '.csv')
RES = re.compile(r'res://([^"\'\)\s%]+)')

used = set()
queue = ['project.godot', 'CREDITS.txt', 'README.txt', 'README.md', 'tools/git_used.py']
queue += [p for p in ALL if p.startswith(('scenes/', 'scripts/', 'shaders/', 'lang/')) and not p.endswith('.import')]
fmt_prefixes = set()   # «book%d», «mb_note%d» — имена звуков с номером
quoted = set()   # все строки в кавычках из скриптов — для путей вида "res://audio/%s.wav"
for p in ALL:
    if p.endswith('.gd'):
        txt_ = open(p, encoding='utf-8', errors='ignore').read()
        quoted |= set(re.findall(r'"([A-Za-z0-9_]+)"', txt_))
        fmt_prefixes |= set(re.findall(r'"([A-Za-z_]+)%d"', txt_))

def add(p):
    p = os.path.normpath(p).replace('\\', '/')
    if p in ALLSET and p not in used:
        used.add(p); queue.append(p)

# динамические пути из скриптов
# res://папка/префикс%s.расширение — берём все файлы с таким префиксом и окончанием
for p in ALL:
    if p.endswith('.gd'):
        for pre, suf in re.findall(r'res://([^"%]+)%[sd]([^"]*)"', open(p, encoding='utf-8', errors='ignore').read()):
            for q in ALL:
                if q.startswith(pre) and q.endswith(suf) and not q.endswith('.import'):
                    # вся папка (res://audio/%s.wav) — только файлы, чьи имена встречаются в скриптах строкой
                    if pre.endswith('/') and os.path.splitext(os.path.basename(q))[0] not in quoted:
                        continue
                    used.add(q); queue.append(q)
for p in ALL:
    stem = os.path.splitext(os.path.basename(p))[0]
    if p.startswith('audio/') and not p.endswith('.import'):
        if re.sub(r'\d+$', '', stem) in fmt_prefixes or stem in quoted or (p.startswith('audio/intro/i_') and stem[2:] in quoted):
            add(p)
    if re.match(r'models/forest/pine/pine\d\.glb$', p):
        add(p)

while queue:
    p = queue.pop()
    used.add(p)
    if p.endswith(TEXT) and os.path.exists(p):
        txt = open(p, encoding='utf-8', errors='ignore').read()
        for r in RES.findall(txt):
            add(r)
        if p.endswith('.gltf'):
            try:
                for it in json.load(open(p, encoding='utf-8')).get('buffers', []) + json.load(open(p, encoding='utf-8')).get('images', []):
                    if 'uri' in it and not it['uri'].startswith('data:'):
                        add(os.path.join(os.path.dirname(p), it['uri']))
            except Exception:
                pass
    # бинарные модели: текстуры рядом, имена которых упомянуты внутри файла
    if p.endswith(('.fbx', '.glb', '.obj', '.blend')):
        data = open(p, 'rb').read()
        d = os.path.dirname(p)
        for q in ALL:
            if q.startswith(d + '/') and q.lower().endswith(('.png', '.jpg', '.jpeg', '.tga', '.webp')):
                if os.path.basename(q).encode() in data:
                    add(q)
    if p.endswith('.obj'):
        add(p[:-4] + '.mtl')
    # текстуры, которые Godot достаёт из FBX/GLB при импорте: <имя>_0.png, <имя>_alpha_1.png …
    if p.endswith(('.fbx', '.glb')):
        stem = os.path.splitext(p)[0] + '_'
        for q in ALL:
            if q.startswith(stem) and q.lower().endswith(('.png', '.jpg')):
                add(q)
    # бинарные сцены Godot (.scn/.res): ссылки res:// внутри
    if p.endswith(('.scn', '.res')):
        for r in re.findall(rb'res://([A-Za-z0-9_./-]+)', open(p, 'rb').read()):
            add(r.decode())
        d = os.path.dirname(p)       # .scn бывает сжат — берём и картинки рядом
        for q in ALL:
            if os.path.dirname(q) == d and q.lower().endswith(('.png', '.jpg', '.jpeg')):
                add(q)
    # английские версии надписей: <имя>_en.png (подменяются по языку)
    if p.lower().endswith(('.png', '.jpg')):
        b, e = os.path.splitext(p)
        add(b + '_en' + e)
    # intro.gd: к дереву подгружается крона <имя>_crown.glb
    if p.endswith('.glb'):
        add(p[:-4] + '_crown.glb')

# vintage.gd: текстуры res://models/vintage/tex/<материал>_* (имена материалов — строки в скриптах)
for q in ALL:
    if q.startswith('models/vintage/tex/') and any(os.path.basename(q).startswith(v + '_') for v in quoted):
        add(q)
while queue:
    used.add(queue.pop())

# к каждому ресурсу — его .import и .uid
for p in list(used):
    for ext in ('.import', '.uid'):
        if p + ext in ALLSET:
            used.add(p + ext)

lines = ['# Создано tools/git_used.py — белый список: в git только то, что использует игра.',
         '/**', '!/**/', '!/.gitignore', '!/.gitattributes']
lines += ['!/' + p for p in sorted(used)]
lines += ['/.godot/', '']
open('.gitignore', 'w').write('\n'.join(lines))
size = sum(os.path.getsize(p) for p in used if os.path.exists(p))
tot = sum(os.path.getsize(p) for p in ALL)
print(f'используется {len(used)} файлов, {size/1e6:.0f} МБ из {len(ALL)} файлов, {tot/1e6:.0f} МБ')
