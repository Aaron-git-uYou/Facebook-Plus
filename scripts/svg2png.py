#!/usr/bin/env python3
"""Rasterise the icon SVGs in resources/svg/ into the @1x/@2x/@3x PNGs the
tweak bundle ships in resources/bundle/.

Each source `resources/svg/<name>.svg` produces three files:

    resources/bundle/<name>.png       (@1x, the base point size)
    resources/bundle/<name>@2x.png    (2x)
    resources/bundle/<name>@3x.png    (3x)

Base point sizes match what the app expects: 40pt for the row/feature glyphs,
120pt for the logo. Override with --base if you add a differently sized asset.

Run it with any interpreter that has cairosvg installed (e.g. `pip install
cairosvg`, or an activated virtualenv):

    python test/svg2png.py                # rebuild every SVG
    python test/svg2png.py eye            # rebuild just eye.svg
    python test/svg2png.py eye group      # rebuild a few
    python test/svg2png.py --base 28 foo  # foo.svg at a 28pt base
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import ClassVar

import cairosvg


class SvgRasteriser:
    """Renders resources/svg/*.svg into the bundle's @1x/@2x/@3x PNGs."""

    ROOT = Path(__file__).resolve().parent.parent
    SVG_DIR = ROOT / "resources" / "svg"
    BUNDLE_DIR = ROOT / "resources" / "bundle"

    # Base point size per asset; anything not listed uses DEFAULT_BASE.
    DEFAULT_BASE = 40
    BASE_SIZES: ClassVar[dict[str, int]] = {"logo": 120}

    # The @Nx scales emitted for each asset.
    SCALES: ClassVar[tuple[int, ...]] = (1, 2, 3)

    def __init__(self, base: int | None = None) -> None:
        # An explicit --base overrides the per-asset table for every name.
        self.base_override = base

    def base_size_for(self, name: str) -> int:
        if self.base_override is not None:
            return self.base_override
        return self.BASE_SIZES.get(name, self.DEFAULT_BASE)

    def svg_stems(self) -> list[str]:
        return sorted(p.stem for p in self.SVG_DIR.glob("*.svg"))

    def render(self, name: str) -> None:
        src = self.SVG_DIR / f"{name}.svg"
        if not src.exists():
            print(f"  ! {name}.svg not found in {self.SVG_DIR}", file=sys.stderr)
            return

        base = self.base_size_for(name)
        for scale in self.SCALES:
            px = base * scale
            suffix = "" if scale == 1 else f"@{scale}x"
            out = self.BUNDLE_DIR / f"{name}{suffix}.png"
            cairosvg.svg2png(
                url=str(src),
                write_to=str(out),
                output_width=px,
                output_height=px,
            )
            print(f"  {name}{suffix}.png  ({px}x{px})")

    def run(self, names: list[str]) -> None:
        self.BUNDLE_DIR.mkdir(parents=True, exist_ok=True)
        names = names or self.svg_stems()
        if not names:
            print(f"no SVGs found in {self.SVG_DIR}", file=sys.stderr)
            sys.exit(1)
        for name in names:
            self.render(name)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Rasterise resources/svg/*.svg into the @1x/@2x/@3x bundle PNGs.")
    parser.add_argument(
        "names", nargs="*",
        help="icon name(s) without extension (default: every SVG in resources/svg/)")
    parser.add_argument(
        "--base", type=int, default=None,
        help=f"override the @1x point size for the named icons "
             f"(default {SvgRasteriser.DEFAULT_BASE}, {SvgRasteriser.BASE_SIZES})")
    args = parser.parse_args()

    SvgRasteriser(base=args.base).run(args.names)


if __name__ == "__main__":
    main()
