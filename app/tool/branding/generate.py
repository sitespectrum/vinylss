#!/usr/bin/env python3
"""Generates the Vinylss logo, launcher icons and splash images.

The mark is a record with the amber label from the app (see lib/ui/theme.dart), a "V" printed
on the label and the spindle hole sitting in the crook of the V.

Writes SVG sources to assets/branding/ and renders PNGs with rsvg-convert:

    python3 tool/branding/generate.py      # from app/
"""

import math
import pathlib
import subprocess

APP = pathlib.Path(__file__).resolve().parents[2]
RES = APP / 'android/app/src/main/res'

BACKGROUND = '#0E0E0E'
SURFACE = '#1A1A1A'
VINYL = '#111111'
GROOVE_A = '#1C1C1C'
GROOVE_B = '#151515'
EDGE = '#444444'
ACCENT = '#F2A03D'
ACCENT_EDGE = '#D9822B'
ON_ACCENT = '#1A1206'

DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def mark(cx, cy, r, detail=True):
    """The record, centred on (cx, cy) with radius r. [detail] draws individual grooves."""
    s = []
    s.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{VINYL}"/>')
    if detail:
        g, i = r * 0.42, 0
        while g < r * 0.95:
            gap = abs(g / r - 0.62) < 0.02 or abs(g / r - 0.80) < 0.02
            colour = '#000000' if gap else (GROOVE_A if i % 2 == 0 else GROOVE_B)
            s.append(f'<circle cx="{cx}" cy="{cy}" r="{g:.2f}" fill="none" '
                     f'stroke="{colour}" stroke-width="{r * 0.012:.2f}"/>')
            g += r * 0.03
            i += 1
    else:
        # Too small for grooves: two track gaps keep it reading as a record.
        for f in (0.62, 0.80):
            s.append(f'<circle cx="{cx}" cy="{cy}" r="{r * f:.2f}" fill="none" '
                     f'stroke="#000000" stroke-width="{r * 0.03:.2f}"/>')

    # Light sheen: two opposite wedges over the grooved band.
    for start in (-62, 118):
        a0, a1 = math.radians(start), math.radians(start + 34)
        ro, ri = r * 0.97, r * 0.40
        p = (f'M{cx + ri * math.cos(a0):.2f},{cy + ri * math.sin(a0):.2f} '
             f'L{cx + ro * math.cos(a0):.2f},{cy + ro * math.sin(a0):.2f} '
             f'A{ro:.2f},{ro:.2f} 0 0 1 {cx + ro * math.cos(a1):.2f},{cy + ro * math.sin(a1):.2f} '
             f'L{cx + ri * math.cos(a1):.2f},{cy + ri * math.sin(a1):.2f} '
             f'A{ri:.2f},{ri:.2f} 0 0 0 {cx + ri * math.cos(a0):.2f},{cy + ri * math.sin(a0):.2f} Z')
        s.append(f'<path d="{p}" fill="url(#sheen{start})"/>')
    s.append(f'<circle cx="{cx}" cy="{cy}" r="{r - r * 0.006:.2f}" fill="none" '
             f'stroke="{EDGE}" stroke-width="{r * 0.012:.2f}"/>')

    # Label with the V; the spindle hole sits in the crook of the V.
    lr = r * 0.38
    s.append(f'<circle cx="{cx}" cy="{cy}" r="{lr:.2f}" fill="url(#label)"/>')
    s.append(f'<circle cx="{cx}" cy="{cy}" r="{lr:.2f}" fill="none" stroke="#000000" '
             f'stroke-opacity="0.35" stroke-width="{r * 0.015:.2f}"/>')
    w, top, bottom = lr * 0.54, cy - lr * 0.42, cy + lr * 0.56
    s.append(f'<path d="M{cx - w:.2f},{top:.2f} L{cx:.2f},{bottom:.2f} L{cx + w:.2f},{top:.2f}" '
             f'fill="none" stroke="{ON_ACCENT}" stroke-width="{lr * 0.18:.2f}" '
             f'stroke-linecap="round" stroke-linejoin="round"/>')
    s.append(f'<circle cx="{cx}" cy="{cy}" r="{max(r * 0.036, 1):.2f}" '
             f'fill="{BACKGROUND}"/>')
    return '\n  '.join(s)


def defs(cx, cy, r):
    sheens = []
    for start in (-62, 118):
        mid = math.radians(start + 17)
        # Gradient across the wedge, perpendicular to its bisector.
        dx, dy = -math.sin(mid) * r * 0.5, math.cos(mid) * r * 0.5
        mx, my = cx + math.cos(mid) * r * 0.7, cy + math.sin(mid) * r * 0.7
        sheens.append(
            f'<linearGradient id="sheen{start}" gradientUnits="userSpaceOnUse" '
            f'x1="{mx + dx:.2f}" y1="{my + dy:.2f}" x2="{mx - dx:.2f}" y2="{my - dy:.2f}">'
            '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0"/>'
            '<stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0.16"/>'
            '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>')
    return (
        '<defs>\n'
        f'  <radialGradient id="label" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" '
        f'r="{r * 0.38:.2f}"><stop offset="0" stop-color="{ACCENT}"/>'
        f'<stop offset="1" stop-color="{ACCENT_EDGE}"/></radialGradient>\n'
        f'  <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{SURFACE}"/><stop offset="1" stop-color="{BACKGROUND}"/>'
        '</linearGradient>\n  ' + '\n  '.join(sheens) + '\n</defs>')


def svg(size, body, cx, cy, r):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
            f'viewBox="0 0 {size} {size}">\n{defs(cx, cy, r)}\n  {body}\n</svg>\n')


def tile(size, corner, mark_r, detail=True):
    """The mark on a dark rounded tile (legacy launcher icon, favicon)."""
    c = size / 2
    body = f'<rect width="{size}" height="{size}" rx="{size * corner}" fill="url(#tile)"/>\n  '
    return svg(size, body + mark(c, c, size * mark_r, detail), c, c, size * mark_r)


def bare(size, mark_r, background=None, detail=True):
    """The mark alone, optionally on a full-bleed background (adaptive and maskable icons)."""
    c = size / 2
    body = f'<rect width="{size}" height="{size}" fill="{background}"/>\n  ' if background else ''
    return svg(size, body + mark(c, c, size * mark_r, detail), c, c, size * mark_r)


def monochrome(size, mark_r):
    """Single-colour silhouette for Android themed icons: only the alpha is used."""
    c, r = size / 2, size * mark_r
    lr = r * 0.38
    w, top, bottom = lr * 0.54, c - lr * 0.42, c + lr * 0.56
    cut = 'fill="none" stroke="#000000"'
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 {size} {size}">\n<mask id="m">\n'
        f'  <circle cx="{c}" cy="{c}" r="{r}" fill="#FFFFFF"/>\n'
        f'  <circle cx="{c}" cy="{c}" r="{r * 0.62:.2f}" {cut} stroke-width="{r * 0.05:.2f}"/>\n'
        f'  <circle cx="{c}" cy="{c}" r="{r * 0.80:.2f}" {cut} stroke-width="{r * 0.05:.2f}"/>\n'
        f'  <circle cx="{c}" cy="{c}" r="{lr * 1.12:.2f}" {cut} stroke-width="{r * 0.06:.2f}"/>\n'
        f'  <path d="M{c - w:.2f},{top:.2f} L{c:.2f},{bottom:.2f} L{c + w:.2f},{top:.2f}" {cut} '
        f'stroke-width="{lr * 0.2:.2f}" stroke-linecap="round" stroke-linejoin="round"/>\n'
        f'  <circle cx="{c}" cy="{c}" r="{r * 0.045:.2f}" fill="#000000"/>\n</mask>\n'
        f'<rect width="{size}" height="{size}" fill="#FFFFFF" mask="url(#m)"/>\n</svg>\n')


def render(source, out, px):
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['rsvg-convert', '-w', str(px), '-h', str(px), '-o', str(out), str(source)],
                   check=True)


def main():
    branding = APP / 'assets/branding'
    branding.mkdir(parents=True, exist_ok=True)
    sources = {
        'logo.svg': bare(1024, 0.48),                       # The mark, transparent.
        'icon.svg': tile(1024, 0.22, 0.40),                 # Legacy launcher / favicon.
        'icon_small.svg': tile(64, 0.22, 0.42, detail=False),
        # Adaptive icon foreground: 108dp canvas, mark inside the 66dp safe zone.
        'icon_foreground.svg': bare(432, 0.29),
        'icon_monochrome.svg': monochrome(432, 0.29),
        'icon_maskable.svg': bare(1024, 0.36, BACKGROUND),  # Web maskable: 80% safe zone.
    }
    for name, text in sources.items():
        (branding / name).write_text(text)

    for density, scale in DENSITIES.items():
        render(branding / 'icon.svg', RES / f'mipmap-{density}/ic_launcher.png', round(48 * scale))
        render(branding / 'icon_foreground.svg',
               RES / f'mipmap-{density}/ic_launcher_foreground.png', round(108 * scale))
        render(branding / 'icon_monochrome.svg',
               RES / f'mipmap-{density}/ic_launcher_monochrome.png', round(108 * scale))
        # Pre-Android 12 splash: the mark at 128dp.
        render(branding / 'logo.svg', RES / f'drawable-{density}/splash_logo.png',
               round(128 * scale))

    # In-app splash, drawn at 128 logical px to line up with the native one.
    render(branding / 'logo.svg', branding / 'logo.png', 512)

    web = APP / 'web'
    render(branding / 'icon_small.svg', web / 'favicon.png', 32)
    for px in (192, 512):
        render(branding / 'icon.svg', web / f'icons/Icon-{px}.png', px)
        render(branding / 'icon_maskable.svg', web / f'icons/Icon-maskable-{px}.png', px)

    render(branding / 'icon.svg', APP / 'linux/runner/resources/app_icon.png', 256)


if __name__ == '__main__':
    main()
