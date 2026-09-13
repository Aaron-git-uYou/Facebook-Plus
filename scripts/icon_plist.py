#!/usr/bin/env python3
"""Build the CFBundleIcons merge plist cyan's -l needs to register custom logos.

cyan's -l does a shallow, top-level overwrite of each key, so handing it a bare
CFBundleIcons would wipe Facebook's own icons. IconPlist reads the target's
*actual* CFBundleIcons (and CFBundleIcons~ipad), adds an entry for every fbplus_*
logo in resources/logo/, and writes the complete, merged dict(s) — so cyan can
overwrite the key without losing anything.

Usage:
    python3 scripts/icon_plist.py <Facebook.ipa | Info.plist> <out.plist>
"""

import copy
import glob
import os
import plistlib
import sys
import zipfile


class IconPlist:
    """Assembles the alternate-icon Info.plist fragment for the custom logos."""

    # Variant order matches Facebook's own CFBundleIconFiles arrays.
    VARIANT_SUFFIXES = ("@2x", "@3x", "-iPad@2x", "-iPadPro@2x")

    def __init__(self, repo=None):
        self.repo = repo or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.logo_dir = os.path.join(self.repo, "resources", "logo")

    def read_info(self, target):
        """Load Info.plist from an .ipa or a direct Info.plist path."""
        if target.lower().endswith(".ipa"):
            with zipfile.ZipFile(target) as zf:
                names = [n for n in zf.namelist()
                         if n.startswith("Payload/") and n.endswith(".app/Info.plist")
                         and n.count("/") == 2]
                if not names:
                    sys.exit("no Payload/*.app/Info.plist in the ipa")
                return plistlib.loads(zf.read(names[0]))
        with open(target, "rb") as f:
            return plistlib.load(f)

    def discover_icons(self):
        """{ base -> [existing CFBundleIconFiles entries] } for every fbplus_* logo.

        The base is the plain iPhone @2x file; the -iPad@2x / -iPadPro@2x files are
        idiom variants of it, not bases of their own.
        """
        icons = {}
        for path in sorted(glob.glob(os.path.join(self.logo_dir, "fbplus_*@2x.png"))):
            stem = os.path.basename(path)[:-len("@2x.png")]
            if stem.endswith("-iPad") or stem.endswith("-iPadPro"):
                continue   # an iPad variant of another base, not a base itself
            files = [f"{stem}{s}" for s in self.VARIANT_SUFFIXES
                     if os.path.isfile(os.path.join(self.logo_dir, f"{stem}{s}.png"))]
            icons[stem] = files
        return icons

    def build(self, target):
        """Return the merged CFBundleIcons dict(s) for `target`'s Info.plist."""
        info = self.read_info(target)
        custom = self.discover_icons()
        if not custom:
            sys.exit("no fbplus_* logos in resources/logo/ — run scripts/make_logo.py first")

        merged = {}
        for key in ("CFBundleIcons", "CFBundleIcons~ipad"):
            if key not in info:
                continue
            icons = copy.deepcopy(info[key])
            alternates = icons.setdefault("CFBundleAlternateIcons", {})
            for base, files in custom.items():
                alternates[base] = {"CFBundleIconFiles": files, "UIPrerenderedIcon": False}
            merged[key] = icons

        if not merged:
            sys.exit("target Info.plist has no CFBundleIcons — cannot register alternates")
        return merged, custom

    def write(self, target, out_path):
        merged, custom = self.build(target)
        with open(out_path, "wb") as f:
            plistlib.dump(merged, f)   # xml
        print(f"wrote {out_path}")
        print(f"  registered {len(custom)} custom icon(s): {', '.join(custom)}")
        print(f"  into: {', '.join(merged)}")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    IconPlist().write(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    main()
