#!/usr/bin/env python3
"""Convert a source image into app-icon-sized PNGs for a custom app logo.

Takes a source PNG (default resources/logo.png) and writes square, opaque icon
files into resources/logo/ as fbplus_<name>@2x/@3x + iPad variants.

A transparent source (like resources/logo.png) is handled cleanly: the fully
transparent margin is trimmed so the art fills the frame, and any leftover
transparency — the rounded corners — is filled with the logo's *own* background
colour, auto-detected from its border. That is what stops the icon from showing
a white border. Pass --bg <colour> to force a fill colour instead.

The fbplus_ prefix keeps these clear of the tweak's own brand "logo" art and is
how the App Icon menu recognises a custom logo at runtime. resources/logo/ ships
inside FacebookPlus.bundle, so the icons travel with the tweak; build.sh then
promotes them to the app root and registers them in the app's Info.plist (the
home-screen icon is drawn by SpringBoard from the app bundle, not from ours).

Usage:
    python3 scripts/make_logo.py                       # resources/logo.png -> fbplus_logo.*
    python3 scripts/make_logo.py path/to/source.png    # -> fbplus_source.*
    python3 scripts/make_logo.py source.png neon       # -> fbplus_neon.*
    python3 scripts/make_logo.py source.png neon --bg "#0866FF"   # force fill colour

Requires Pillow:  pip install pillow
"""

import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required:  pip install pillow")

# Pillow 10+ moved the resampling filters onto Image.Resampling.
LANCZOS = Image.Resampling.LANCZOS


class LogoMaker:
    """Renders a source image into the app-icon PNG variants for one custom logo."""

    PREFIX = "fbplus_"
    # The variants the home screen uses, matching Facebook's own alternate icons:
    # iPhone @2x/@3x plus iPad (76pt @2x = 152) and iPad Pro (83.5pt @2x = 167).
    VARIANTS = {"@2x": 120, "@3x": 180, "-iPad@2x": 152, "-iPadPro@2x": 167}

    def __init__(self, repo=None):
        self.repo = repo or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.out_dir = os.path.join(self.repo, "resources", "logo")

    # ---- colour helpers --------------------------------------------------

    def parse_bg(self, value):
        """'#RRGGBB' / 'white' / 'black' / 'auto' -> (r, g, b) or None (auto)."""
        value = (value or "").strip().lower()
        if value in ("", "auto"):
            return None
        named = {"white": (255, 255, 255), "black": (0, 0, 0)}
        if value in named:
            return named[value]
        if value.startswith("#"):
            value = value[1:]
        if len(value) == 6:
            return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))
        sys.exit(f"bad --bg colour: {value!r}")

    def auto_background(self, img):
        """The logo's own background colour: the median of the opaque pixels around
        its border. Filling leftover transparency with this keeps corners from
        turning white."""
        rgba = img.convert("RGBA")
        w, h = rgba.size
        px = rgba.load()
        step = max(1, min(w, h) // 96)
        reds, greens, blues = [], [], []

        def sample(x, y):
            r, g, b, a = px[x, y]
            if a > 200:
                reds.append(r); greens.append(g); blues.append(b)

        for x in range(0, w, step):
            sample(x, 0); sample(x, h - 1)
        for y in range(0, h, step):
            sample(0, y); sample(w - 1, y)
        if not reds:
            return (255, 255, 255)
        mid = len(reds) // 2
        return (sorted(reds)[mid], sorted(greens)[mid], sorted(blues)[mid])

    # ---- image steps -----------------------------------------------------

    def trim_transparent(self, img):
        """Crop away the fully-transparent margin so the logo fills the icon frame
        instead of floating in padding — that padding is what showed as a border."""
        if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
            rgba = img.convert("RGBA")
            bbox = rgba.getchannel("A").getbbox()
            return rgba.crop(bbox) if bbox else rgba
        return img

    def square_cover(self, img):
        """Center-crop to a square so the icon fills the frame without distortion."""
        w, h = img.size
        if w == h:
            return img
        side = min(w, h)
        left, top = (w - side) // 2, (h - side) // 2
        return img.crop((left, top, left + side, top + side))

    def flatten(self, img, bg):
        """Composite onto an opaque background — iOS app icons must not be transparent."""
        if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
            img = img.convert("RGBA")
            base = Image.new("RGBA", img.size, bg + (255,))
            base.alpha_composite(img)
            return base.convert("RGB")
        return img.convert("RGB")

    # ---- entry point -----------------------------------------------------

    def make(self, source, name, bg=None):
        """Write every fbplus_<name> variant from `source`. bg None = auto-detect."""
        if not os.path.isfile(source):
            sys.exit(f"source not found: {source}")

        img = self.square_cover(self.trim_transparent(Image.open(source)))
        if bg is None:                       # auto: match the logo's own background
            bg = self.auto_background(img)
        print(f"  background fill: #{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}")
        img = self.flatten(img, bg)

        os.makedirs(self.out_dir, exist_ok=True)
        for suffix, size in self.VARIANTS.items():
            out = os.path.join(self.out_dir, f"{self.PREFIX}{name}{suffix}.png")
            img.resize((size, size), LANCZOS).save(out, "PNG")
            print(f"  {os.path.relpath(out, self.repo)}  ({size}x{size})")


def main():
    args = list(sys.argv[1:])
    maker = LogoMaker()

    bg = None   # None = auto-detect the logo's own background colour
    if "--bg" in args:
        i = args.index("--bg")
        bg = maker.parse_bg(args[i + 1] if i + 1 < len(args) else "auto")
        del args[i:i + 2]

    source = args[0] if len(args) > 0 else os.path.join(maker.repo, "resources", "logo.png")
    name = args[1] if len(args) > 1 else os.path.splitext(os.path.basename(source))[0]

    print(f"source: {os.path.relpath(source, maker.repo) if source.startswith(maker.repo) else source}")
    maker.make(source, name, bg)


if __name__ == "__main__":
    main()
