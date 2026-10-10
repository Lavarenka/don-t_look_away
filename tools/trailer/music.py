# Музыка трейлера: низкий гул, ветер, нарастание, сердцебиение, тишина перед скримером, удар на названии.
import numpy as np, wave, sys
SR = 48000
T = float(sys.argv[1]) if len(sys.argv) > 1 else 55.0
SCARE = float(sys.argv[2]) if len(sys.argv) > 2 else 47.75
TITLE = float(sys.argv[3]) if len(sys.argv) > 3 else 49.6
n = int(SR * T)
t = np.arange(n) / SR
rng = np.random.default_rng(7)

def lp(x, a):           # однополюсный НЧ-фильтр
    y = np.empty_like(x); acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc); y[i] = acc
    return y

def env(t0, t1, fade_in=1.0, fade_out=1.0):
    e = np.clip((t - t0) / fade_in, 0, 1) * np.clip((t1 - t) / fade_out, 0, 1)
    return e

out = np.zeros(n)
# 1) гул: ля контроктавы + квинта, медленные биения
for f, a in ((55.0, 0.35), (55.4, 0.25), (82.4, 0.12), (110.2, 0.06)):
    out += a * np.sin(2 * np.pi * f * t + 0.3 * np.sin(2 * np.pi * 0.07 * t))
drone_env = env(0.5, SCARE - 0.25, 4.0, 0.05) * (0.55 + 0.45 * np.clip((t - 25) / (SCARE - 25), 0, 1))
out *= drone_env
# 2) ветер: шум через НЧ-фильтр, «дышит»
w = rng.standard_normal(n)
w = np.convolve(w, np.ones(64) / 64, mode='same')
w = np.convolve(w, np.ones(32) / 32, mode='same')
out += 0.9 * w * (0.4 + 0.3 * np.sin(2 * np.pi * 0.11 * t)) * env(0.0, SCARE - 0.25, 3.0, 0.05)
# 3) нарастание: «скрипучий» тон, ползущий вверх с 30 с до скримера
rise = (t >= 29.0) & (t < SCARE - 0.25)
k = np.clip((t - 29.0) / (SCARE - 0.25 - 29.0), 0, 1)
fr = 220 * (1 + 1.5 * k ** 2)
ph = 2 * np.pi * np.cumsum(fr) / SR
saw = 2 * ((ph / (2 * np.pi)) % 1.0) - 1
out += rise * 0.10 * k ** 1.5 * (np.sin(ph) * 0.6 + saw * 0.25) * (1 + 0.3 * np.sin(2 * np.pi * 6 * t))
# 4) сердцебиение: с 36 с, всё чаще
hb = np.zeros(n)
tt = 36.0
while tt < SCARE - 0.4:
    bpm = 60 + 70 * (tt - 36.0) / (SCARE - 36.0)
    for off, amp in ((0.0, 1.0), (0.22, 0.6)):
        s = int((tt + off) * SR); L = int(0.18 * SR)
        if s + L < n:
            x = np.arange(L) / SR
            hb[s:s + L] += amp * np.sin(2 * np.pi * 48 * x) * np.exp(-x * 28)
    tt += 60.0 / bpm
out += 0.9 * hb
# 5) удары на смене планов (короткий низкий «бум»)
def boom(at, amp=1.0, f0=60, dec=3.0):
    s = int(at * SR); L = int(min(4.0, T - at) * SR)
    x = np.arange(L) / SR
    sig = np.sin(2 * np.pi * (f0 * x + 25 * (1 - np.exp(-x * 8)) / 8)) * np.exp(-x * dec)
    nz = rng.standard_normal(L) * np.exp(-x * 14) * 0.3
    out[s:s + L] += amp * (sig + nz)
for at in (12.1, 29.0):
    boom(at, 0.6)
# 6) название: тяжёлый удар с долгим хвостом и тихий гул под ним
boom(TITLE, 1.4, 42, 0.9)
out += env(TITLE, T, 0.3, 2.0) * 0.18 * np.sin(2 * np.pi * 41.2 * t)
# тишина перед скримером
out *= np.where((t > SCARE - 0.25) & (t < TITLE), 0.0, 1.0)
out = out / np.max(np.abs(out)) * 0.85
st = np.stack([out, out * 0.98], axis=1)
with wave.open("music.wav", "wb") as f:
    f.setnchannels(2); f.setsampwidth(2); f.setframerate(SR)
    f.writeframes((st * 32767).astype(np.int16).tobytes())
print("ok", T)
