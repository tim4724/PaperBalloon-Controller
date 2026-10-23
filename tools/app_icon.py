#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["skia-pathops", "fonttools"]
# ///
"""Draw the launcher icon for both apps from one geometry and write every file that carries it.

    uv run tools/app_icon.py

The icon is a quilted hot-air balloon (four gores; four scalloped rings, the first closing a
solid crown cap, the last opening the skirt) carrying the tilted phone-pad glyph on two ropes,
in white on a raspberry -> orange tile, authored on a 100-unit tile. Android shows it in light
and dark. iOS 26 renders it as glass and derives its own dark icon from it; the iOS 17-18 dark
fallback (AppIcon-Dark.png) approximates that as a sunset balloon on graphite. The quilt seams
are cut out of the shape with path booleans rather than painted in the tile colour, so the
alpha-only layers (Android themed icon, iOS tinted) keep them.

Deliberately NOT a build step, like encode_artwork.sh: run it when the icon changes and commit
what it writes. Rasters are rendered with headless Google Chrome and ImageMagick (macOS paths).
"""
import json, math, os, subprocess, tempfile
import pathops
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.svgLib.path import parse_path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

TILE = ('#F7266D', '#FF8A1F')  # top to bottom of the tile
ART = '#FFFFFF'

# ---- geometry, in 100-unit tile coordinates ----

TOP, EQ, THROAT = 7, 31, 63      # heights of the crown, the widest point and the throat
EQ_HALF, THROAT_HALF = 29, 7     # half-widths at the widest point and the throat
GORES, SEAM = 4, 2.4
RINGS = [16, 30, 43, 54]         # the first closes the crown cap, the last opens the skirt
U = [-1 + 2 * k / GORES for k in range(GORES + 1)]  # gore edges, -1 (left) to 1 (right)

def half_width(y):
    # half-width of the envelope at height y: elliptical dome, cosine taper to the throat
    if y <= EQ:
        return EQ_HALF * math.sqrt(max(0, 1 - ((EQ - y) / (EQ - TOP)) ** 2))
    s = (y - EQ) / (THROAT - EQ)
    return THROAT_HALF + (EQ_HALF - THROAT_HALF) * math.cos(math.pi / 2 * s) ** 1.15

def pt(u, y): return f'{50 + u * half_width(y):.3f} {y:.3f}'
def ys(a, b, n): return [a + (b - a) * k / n for k in range(n + 1)]

def ring(y):
    # one scalloped ring across all gores, each scallop bulging upward
    return f'M{pt(-1, y)} ' + ' '.join(
        f'Q{50 + (u0 + u1) / 2 * half_width(y):.3f} {y - 2.2:.3f} {pt(u1, y)}' for u0, u1 in zip(U, U[1:]))

OUTLINE = 'M' + ' L'.join([pt(1, y) for y in ys(TOP, THROAT, 60)] + [pt(-1, y) for y in ys(THROAT, TOP, 60)]) + ' Z'
SEAMS = ''.join(f'M{pt(u, RINGS[0])} L' + ' L'.join(pt(u, y) for y in ys(RINGS[0], RINGS[-1], 30)) + ' '
                for u in U[1:-1]) + ' '.join(ring(y) for y in RINGS)
ROPES = 'M44.5 62.5 L37.7 73.4 M55.5 62.5 L60.2 70.6'  # ends run a little into the pad, so they join it
PAD = ('M34.55,43.86 L69.9,38.89 A7.65,7.65 0 0 1 78.54,45.4 L79.96,55.5 A7.65,7.65 0 0 1 73.45,64.14 L38.1,69.11 A7.65,7.65 0 0 1 29.46,62.6 L28.04,52.5 A7.65,7.65 0 0 1 34.55,43.86 Z '
       'M40.48,49.46 L42.17,49.22 A1.27,1.27 0 0 1 43.61,50.31 L44.02,53.25 L46.97,52.84 A1.27,1.27 0 0 1 48.41,53.92 L48.65,55.61 A1.27,1.27 0 0 1 47.57,57.05 L44.62,57.47 L45.03,60.41 A1.27,1.27 0 0 1 43.94,61.85 L42.26,62.08 A1.27,1.27 0 0 1 40.83,61 L40.41,58.05 L37.46,58.47 A1.27,1.27 0 0 1 36.02,57.38 L35.78,55.7 A1.27,1.27 0 0 1 36.87,54.26 L39.81,53.85 L39.41,50.9 A1.27,1.27 0 0 1 40.48,49.46 Z '
       'M63.83,53.74 A2.72,2.72 0 1 1 64.59,59.12 A2.72,2.72 0 1 1 63.83,53.74 Z '
       'M67.82,45.45 A2.72,2.72 0 1 1 68.58,50.84 A2.72,2.72 0 1 1 67.82,45.45 Z')
PAD_AT = (0.7, 0, 0, 0.7, 12.2, 41)  # the glyph's own grid onto the tile; its -8 degree tilt is baked into PAD

def path(d):
    p = pathops.Path()
    parse_path(d, p.getPen())
    return p

def stroked(d, width):
    p = path(d)
    p.stroke(width, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
    p.convertConicsToQuads()
    return p

def union(a, b): return pathops.op(a, b, pathops.PathOp.UNION)

pad = path(PAD).transform(*PAD_AT)
# the buttons are holes (set after transform(), which returns a fresh path); the union below folds
# them into the plain winding that SVG and Android draw
pad.fillType = pathops.FillType.EVEN_ODD
quilt = pathops.op(path(OUTLINE), stroked(SEAMS, SEAM), pathops.PathOp.DIFFERENCE)
shape = union(union(quilt, stroked(ROPES, 3)), pad).transform(1, 0, 0, 1, 0, 1)  # 1 unit low balances the basket
pen = SVGPathPen(None, ntos=lambda v: f'{v:.2f}'.rstrip('0').rstrip('.'))
shape.draw(pen)
D = pen.getCommands()

def write(rel, text):
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w') as f:
        f.write(text)

# ---- Android adaptive icon ----

FG_S = 0.64  # the 100-unit tile maps onto the central 64dp: a little inside the 72dp visible area, for margin
FG_T = 54 - 50 * FG_S

def vector(comment, body, aapt=False):
    ns = '\n    xmlns:aapt="http://schemas.android.com/aapt"' if aapt else ''
    return (f'<?xml version="1.0" encoding="utf-8"?>\n{comment}\n'
            f'<vector xmlns:android="http://schemas.android.com/apk/res/android"{ns}\n'
            '    android:width="108dp"\n    android:height="108dp"\n    android:viewportWidth="108"\n    android:viewportHeight="108">\n'
            f'{body}</vector>\n')

RES = 'android/app/src/main/res/'
write(RES + 'drawable/ic_launcher_foreground.xml', vector(
    '<!-- The launcher balloon in white, generated by tools/app_icon.py (edit that, not this). The\n'
    '     100-unit tile maps onto the central 64dp of the adaptive canvas; the quilt seams and the\n'
    '     pad\'s buttons are cut out, so the tile shows through. Same icon in light and dark, and\n'
    '     also the themed-icon (monochrome) layer. -->',
    f'    <group\n        android:translateX="{FG_T:g}"\n        android:translateY="{FG_T:g}"\n'
    f'        android:scaleX="{FG_S}"\n        android:scaleY="{FG_S}">\n'
    f'        <path\n            android:fillColor="{ART}"\n            android:pathData="{D}" />\n    </group>\n'))
write(RES + 'drawable/ic_launcher_background.xml', vector(
    '<!-- Sunset tile, generated by tools/app_icon.py: raspberry at the top of the visible 72dp to\n'
    '     orange at its bottom, in light and dark. -->',
    '    <path\n        android:pathData="M0,0h108v108h-108z">\n'
    '        <aapt:attr name="android:fillColor">\n'
    '            <gradient\n                android:type="linear"\n'
    '                android:startX="54"\n                android:startY="18"\n'
    '                android:endX="54"\n                android:endY="90"\n'
    f'                android:startColor="{TILE[0]}"\n                android:endColor="{TILE[1]}" />\n'
    '        </aapt:attr>\n    </path>\n', aapt=True))

# ---- iOS AppIcon.icon ----

HEAD = '<?xml version="1.0" encoding="UTF-8"?>\n<!-- Generated by tools/app_icon.py. -->\n'
SVG = '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
ICON = 'ios/PaperBalloon/AppIcon.icon/'
write(ICON + 'Assets/balloon.svg', f'{HEAD}{SVG}<g transform="scale(10.24)"><path fill="{ART}" d="{D}"/></g></svg>\n')

def srgb(c): return 'srgb:' + ','.join(f'{int(c[i:i + 2], 16) / 255:.5f}' for i in (1, 3, 5)) + ',1.00000'
icon = {
  'fill': {'linear-gradient': [srgb(TILE[0]), srgb(TILE[1])],
           'orientation': {'start': {'x': 0.5, 'y': 0}, 'stop': {'x': 0.5, 'y': 1}}},
  # frosted so the glass reads at home-screen size; low translucency because more washes the small pad out
  'groups': [{'layers': [{'glass': True, 'name': 'balloon', 'image-name': 'balloon.svg'}],
              'blur-material': 0.6, 'lighting': 'individual', 'shadow': {'kind': 'layer-color', 'opacity': 0.6},
              'specular': True, 'translucency': {'enabled': True, 'value': 0.2}}],
  'supported-platforms': {'circles': ['watchOS'], 'squares': 'shared'},
}
write(ICON + 'icon.json', json.dumps(icon, indent=2, separators=(',', ' : ')) + '\n')

# ---- home-screen sky balloons: the icon's shape, cropped to the art, as a silhouette ----

# One file per platform, filled black: the apps paint it through the fleet's gradients
# (Android SkyBackdrop masks a brush with it, iOS masks a LinearGradient), so the four
# balloon colours and their night variants live in the theme, not in assets.
X0, Y0, X1, Y1 = shape.bounds
VW, VH = f'{X1 - X0:.2f}', f'{Y1 - Y0:.2f}'
write(RES + 'drawable/sky_balloon.xml',
      '<?xml version="1.0" encoding="utf-8"?>\n'
      '<!-- The launcher balloon as a silhouette for the home-screen sky, generated by\n'
      '     tools/app_icon.py; SkyBackdrop paints it in the fleet\'s colours. -->\n'
      '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
      f'    android:width="{VW}dp"\n    android:height="{VH}dp"\n'
      f'    android:viewportWidth="{VW}"\n    android:viewportHeight="{VH}">\n'
      f'    <group\n        android:translateX="{-X0:.2f}"\n        android:translateY="{-Y0:.2f}">\n'
      f'        <path\n            android:fillColor="#000000"\n            android:pathData="{D}" />\n'
      '    </group>\n</vector>\n')
# The Android 12+ splash icon: the fleet's lead balloon on the top of the home sky, floating
# up as the splash leaves (SplashLiftOff.kt). The splash can't paint through the theme, so
# its sunset gradients (Color.kt's FleetSunset / FleetSunsetNight) are baked in, by day and
# night. The balloon stands SPLASH_H tall in the 288-unit canvas, inside the 192-unit circle
# the splash keeps.
SPLASH_H = 140
# Keep in sync with Color.kt's FleetSunset and FleetSunsetNight.
for folder, (c0, c1) in (('drawable', ('#F2216A', '#FA6A2C')), ('drawable-night', ('#FF4F86', '#FF9640'))):
    s = SPLASH_H / (Y1 - Y0)
    write(RES + folder + '/splash_balloon.xml',
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<!-- The splash icon: the fleet\'s lead balloon in its sunset, generated by tools/app_icon.py. -->\n'
          '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
          '    xmlns:aapt="http://schemas.android.com/aapt"\n'
          '    android:width="288dp"\n    android:height="288dp"\n'
          '    android:viewportWidth="288"\n    android:viewportHeight="288">\n'
          f'    <group\n        android:translateX="{144 - s * (X0 + X1) / 2:.2f}"\n        android:translateY="{144 - s * (Y0 + Y1) / 2:.2f}"\n'
          f'        android:scaleX="{s:.4f}"\n        android:scaleY="{s:.4f}">\n'
          f'        <path\n            android:pathData="{D}">\n'
          '            <aapt:attr name="android:fillColor">\n'
          '                <gradient\n                    android:type="linear"\n'
          f'                    android:startX="{(X0 + X1) / 2:.2f}"\n                    android:startY="{Y0:.2f}"\n'
          f'                    android:endX="{(X0 + X1) / 2:.2f}"\n                    android:endY="{Y1:.2f}"\n'
          f'                    android:startColor="{c0}"\n                    android:endColor="{c1}" />\n'
          '            </aapt:attr>\n        </path>\n    </group>\n</vector>\n')
write('ios/PaperBalloon/Assets.xcassets/SkyBalloon.imageset/sky-balloon.svg',
      f'{HEAD}<svg xmlns="http://www.w3.org/2000/svg" width="{VW}" height="{VH}" viewBox="{X0:.2f} {Y0:.2f} {VW} {VH}">'
      f'<path fill="#000000" d="{D}"/></svg>\n')
write('ios/PaperBalloon/Assets.xcassets/SkyBalloon.imageset/Contents.json', json.dumps({
  'images': [{'filename': 'sky-balloon.svg', 'idiom': 'universal'}],
  'info': {'author': 'xcode', 'version': 1},
  'properties': {'preserves-vector-representation': True},
}, indent=2, separators=(',', ' : ')) + '\n')

# ---- rasters: iOS 17-18 appiconset, Android legacy mipmaps ----

DARK_TILE = '#202024'  # graphite, under the sunset balloon of the iOS 17-18 dark fallback

def grad(gid, y0, y1):
    # the tile colors top to bottom between y0 and y1, in tile units
    return (f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" x1="0" y1="{y0}" x2="0" y2="{y1}">'
            f'<stop offset="0" stop-color="{TILE[0]}"/><stop offset="1" stop-color="{TILE[1]}"/></linearGradient>')

def tile_svg(bg, art=ART, clip='<rect width="100" height="100"/>'):
    # url(#t) paints across the tile, url(#a) across the art (crown 8 to basket 81)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 100 100">'
            f'<defs>{grad("t", 0, 100)}{grad("a", 8, 81)}<clipPath id="c">{clip}</clipPath></defs>'
            f'<g clip-path="url(#c)"><rect width="100" height="100" fill="{bg}"/><path fill="{art}" d="{D}"/></g></svg>')

with tempfile.TemporaryDirectory() as tmp:
    def render(name, svg):
        src, png = os.path.join(tmp, name + '.svg'), os.path.join(tmp, name + '.png')
        with open(src, 'w') as f:
            f.write(svg)
        subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                        '--window-size=1024,1024', '--default-background-color=00000000', f'--user-data-dir={tmp}/chrome',
                        f'--screenshot={png}', 'file://' + src], check=True, capture_output=True)
        return png
    full = render('full', tile_svg('url(#t)'))
    dark = render('dark', tile_svg(DARK_TILE, art='url(#a)'))
    tinted = render('tinted', tile_svg('#000000'))
    square = render('square', tile_svg('url(#t)', clip='<rect width="100" height="100" rx="14"/>'))
    round_ = render('round', tile_svg('url(#t)', clip='<circle cx="50" cy="50" r="50"/>'))

    sets = os.path.join(ROOT, 'ios/PaperBalloon/Assets.xcassets/AppIcon.appiconset/')
    magick = lambda *a: subprocess.run(['magick', *a], check=True)
    stable = ('-define', 'png:exclude-chunks=date,time')  # no write timestamps, so a rerun leaves git clean
    magick(full, '-alpha', 'off', *stable, 'PNG24:' + sets + 'AppIcon.png')
    magick(dark, '-alpha', 'off', *stable, 'PNG24:' + sets + 'AppIcon-Dark.png')
    magick(tinted, '-alpha', 'off', '-colorspace', 'Gray', *stable, sets + 'AppIcon-Tinted.png')
    for dpi, px in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        for src, name in ((square, 'ic_launcher'), (round_, 'ic_launcher_round')):
            magick(src, '-resize', f'{px}x{px}', '-define', 'webp:lossless=true',
                   os.path.join(ROOT, f'{RES}mipmap-{dpi}/{name}.webp'))
