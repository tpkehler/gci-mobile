"""Render the Jam belief-field glyph to assets/icon.png (1024px, full-bleed ink).

Mirrors the brand sheet glyph (authored in a 116pt box): three concentric teal
rings, five deep-teal rim voices, four teal inner voices, and a bright light-teal
coherent center.
"""
from PIL import Image, ImageDraw

BOX = 116
SS = 8                      # supersample factor for smooth edges
S = 128 * SS               # render canvas
OUT = 1024
k = S / BOX
C = 58 * k

INK = (28, 30, 34)
DEEP = (92, 139, 132)
TEAL = (116, 179, 170)
LIGHT = (168, 214, 206)
OUTER = (53, 74, 72)       # #3F5D58 @ 0.7 over ink, pre-blended

img = Image.new("RGB", (S, S), INK)
d = ImageDraw.Draw(img)


def ring(r, color, w):
    bb = [C - r * k, C - r * k, C + r * k, C + r * k]
    d.ellipse(bb, outline=color, width=max(1, round(w * k)))


def dot(x, y, r, color):
    bb = [x * k - r * k, y * k - r * k, x * k + r * k, y * k + r * k]
    d.ellipse(bb, fill=color)


ring(42, OUTER, 1.4)
ring(29, DEEP, 1.6)
ring(16, TEAL, 2.0)

for x, y in [(58, 16), (96, 46), (82, 92), (28, 88), (20, 44)]:
    dot(x, y, 3.4, DEEP)
for x, y in [(58, 29), (83, 58), (58, 87), (33, 58)]:
    dot(x, y, 3.8, TEAL)
dot(58, 58, 8, LIGHT)

img.resize((OUT, OUT), Image.LANCZOS).save("assets/icon.png")
print("wrote assets/icon.png")
