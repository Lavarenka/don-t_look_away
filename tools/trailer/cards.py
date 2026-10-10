# Титры трейлера: шрифт игры (Cormorant SC), цвет «кость», разрядка как в меню.
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import sys
W, H = int(sys.argv[1]), int(sys.argv[2])
import os
HERE = os.path.dirname(os.path.abspath(__file__))
F = os.path.join(HERE, "..", "..", "fonts", "CormorantSC-Light.ttf")
BONE = (232, 224, 209)
s = H / 1080

def spaced(draw, text, font, y, fill, spacing):
    widths = [draw.textlength(ch, font=font) for ch in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x = (W - total) / 2
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=font, fill=fill)
        x += w + spacing

def card(name, lines, size=58, title=False):
    im = Image.new("RGB", (W, H), (0, 0, 0))
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(im); g = ImageDraw.Draw(glow)
    total_h = 0
    fonts = []
    for i, (txt, sz) in enumerate(lines):
        f = ImageFont.truetype(F, int(sz * s))
        fonts.append(f)
        total_h += f.getbbox("Hg")[3] + int(28 * s)
    y = (H - total_h) / 2
    for (txt, sz), f in zip(lines, fonts):
        sp = sz * s * (0.22 if sz > 100 else 0.18)
        if title and sz > 100:
            spaced(g, txt, f, y, (150, 20, 15), sp)
        spaced(d, txt, f, y, BONE, sp)
        y += f.getbbox("Hg")[3] + int(28 * s)
    if title:
        glow = glow.filter(ImageFilter.GaussianBlur(18 * s))
        im = Image.blend(im, Image.eval(glow, lambda v: min(255, v * 2)), 0.0)
        im = Image.fromarray(__import__("numpy").maximum(__import__("numpy").array(im), __import__("numpy").array(glow)))
    im.save(os.path.join(HERE, name))

card("c1.png", [("GRANDMA'S HOUSE HAS BEEN EMPTY FOR YEARS", 46)])
card("c2.png", [("BUT SOMETHING NEVER LEFT", 50)])
card("c3.png", [("WHATEVER YOU SEE IN THE DARK", 50)])
card("c4.png", [("NEVER TURN YOUR BACK ON IT", 50)])
card("title.png", [("DON'T LOOK AWAY", 120), ("WISHLIST NOW ON STEAM", 38)], title=True)
print("cards ok")
