"""Release guard: no account data in the sources of a build or in the built app.

usage:
  python -I tools/check-build.py --properties                 before building
  python -I tools/check-build.py bin/release/x/zappka-dev.prg  after building (one or more .prg)

Fails (exit 1) when:
- resources/settings/properties.xml has a non-empty default value;
- the compiler's <name>-settings.json next to a .prg is missing or has a non-empty default;
- a .prg contains any run of 64+ hex characters (a secret baked into the binary), including the
  public example secret: release builds must carry no account at all.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEX_RUN = re.compile(rb"[0-9a-fA-F]{64,}")


def check_properties():
    path = os.path.join(ROOT, "resources", "settings", "properties.xml")
    errors = []
    # Our own tracked file; a regex avoids depending on an XML parser.
    text = open(path, encoding="utf-8").read()
    props = re.findall(r'<property\s+id="([^"]+)"[^>]*?(?:/>|>(.*?)</property>)', text, re.S)
    if not props:
        errors.append("properties.xml: no properties found")
    for pid, value in props:
        if value.strip():
            errors.append("properties.xml: property '%s' has a non-empty default" % pid)
    return errors


def check_prg(prg):
    errors = []
    if not os.path.isfile(prg):
        return ["%s: file not found" % prg]
    settings = prg[:-4] + "-settings.json" if prg.endswith(".prg") else prg + "-settings.json"
    if not os.path.isfile(settings):
        errors.append("%s: missing (cannot prove the settings defaults are empty)" % settings)
    else:
        data = json.load(open(settings, encoding="utf-8"))
        items = data.get("settings")
        if not isinstance(items, list) or not items:
            errors.append("%s: no settings list" % settings)
        else:
            for s in items:
                if s.get("defaultValue") not in ("", None):
                    errors.append("%s: setting '%s' has a non-empty default" % (settings, s.get("key")))
    blob = open(prg, "rb").read()
    runs = HEX_RUN.findall(blob)
    if runs:
        errors.append("%s: %d hex run(s) of 64+ characters inside the binary" % (prg, len(runs)))
    return errors


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    errors = []
    for a in argv:
        errors += check_properties() if a == "--properties" else check_prg(a)
    for e in errors:
        print("FAIL", e)
    if not errors:
        print("OK:", ", ".join(os.path.basename(a) for a in argv))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
