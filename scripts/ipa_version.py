#!/usr/bin/env python3
"""Print an IPA's marketing version (CFBundleShortVersionString).

build.sh uses this to name the injected IPA after the exact Facebook build it
targets. The version is read from the app's top-level Info.plist inside the .ipa
(a zip); CFBundleVersion is used as a fallback, then "unknown".

Usage:
    python3 scripts/ipa_version.py <path-to-ipa>
"""

import plistlib
import sys
import zipfile


def app_version(ipa_path):
    with zipfile.ZipFile(ipa_path) as ipa:
        # The main app's Info.plist is the shallowest Payload/<App>.app/Info.plist;
        # deeper matches belong to bundled plugins or frameworks.
        plists = sorted(
            (name for name in ipa.namelist()
             if name.startswith("Payload/") and name.endswith(".app/Info.plist")),
            key=lambda name: name.count("/"),
        )
        if not plists:
            sys.exit("error: no app Info.plist found in IPA")
        info = plistlib.loads(ipa.read(plists[0]))
        return (info.get("CFBundleShortVersionString")
                or info.get("CFBundleVersion")
                or "unknown")


def main(argv):
    if len(argv) != 2:
        sys.exit(f"usage: {argv[0]} <path-to-ipa>")
    print(app_version(argv[1]))


if __name__ == "__main__":
    main(sys.argv)
