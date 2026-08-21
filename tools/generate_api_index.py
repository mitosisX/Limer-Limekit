"""Emit scripts/data/api_index.lua -- everything Limekit exposes to Lua.

    python tools/generate_api_index.py            # write the file
    python tools/generate_api_index.py --check    # fail if it is stale

Limer used to carry three hand-maintained lists (widgets, app utils, python
utils). By the time anyone checked, six of the widgets it advertised no
longer existed, twenty-nine real ones were missing, and thirty-four of the
seventy-one "app utils" had been gone since 1.x. Hand-maintained lists of a
moving API rot; generated ones cannot.

The registry is the same source the LSP stubs and the manifest are built
from, so this file is correct by construction. Run --check in CI, or just
re-run the generator whenever Limekit moves.

Limekit is found via $LIMEKIT_REPO, falling back to a sibling checkout.
"""

import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIMER = HERE.parent
TARGET = LIMER / "scripts" / "data" / "api_index.lua"


def find_limekit():
    env = os.environ.get("LIMEKIT_REPO")
    candidates = [Path(env)] if env else []
    candidates.append(LIMER.parent / "Limekit")
    for candidate in candidates:
        if (candidate / "limekit" / "kernel" / "registry.py").exists():
            return candidate
    raise SystemExit(
        "cannot find the Limekit checkout -- set LIMEKIT_REPO to point at it"
    )


sys.path.insert(0, str(find_limekit()))

from limekit.kernel import introspect, manifest       # noqa: E402
from limekit.kernel.registry import registry          # noqa: E402


_SENTENCE_END = re.compile(r"(?<=[.!?])\s+(?=[A-Z`])")


def one_line(text):
    """The first sentence of a docstring, flattened onto one line.

    The palette shows one line per entry, and a handful of Limekit's
    docstrings carry a second sentence aimed at whoever maintains the
    wrapper rather than whoever calls it -- "Qt native re-exposed so Lua's
    colon syntax works", and so on. The LSP stubs and the docs site still
    carry the whole thing; here it would just be noise.
    """
    text = " ".join((text or "").split())
    if not text:
        return ""
    first = _SENTENCE_END.split(text, 1)[0]
    # A leading abbreviation ("cf. the note") is not a sentence; keep going.
    return first if len(first) >= 20 else text


def quote(text):
    """A Lua long-bracket-free string literal: escape what Lua cares about."""
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def params(info):
    names = [name for name, _, _ in info.params]
    if info.has_varargs:
        names.append("...")
    return ", ".join(names)


def entries_for(module, name, cls):
    """(qualified, kind, snippet, signature, doc) for one registered class."""
    qualified = f"{module}.{name}"
    out = []

    ctor = introspect.constructor(cls)
    if ctor is not None:
        arguments = params(ctor)
        out.append((
            qualified, "class",
            f"{qualified}({arguments})",
            f"{qualified}({arguments})",
            one_line(ctor.doc) or f"Creates a {name}.",
        ))
    else:
        # Service classes (fs.FileSystem, sys.System) are never constructed;
        # they are namespaces of static methods.
        out.append((qualified, "class", qualified, qualified,
                    one_line(cls.__doc__) or f"The {qualified} namespace."))

    for prop in cls.__props__:
        getter, setter, alias = prop.accessor_names()
        if not hasattr(cls, getter) or not hasattr(cls, setter):
            continue
        doc = one_line(prop.doc) or f"the {prop.name} property"
        options = getattr(prop.coerce, "options", None)
        hint = "|".join(sorted(options)) if options else None
        out.append((f"{qualified}:{getter}", "property",
                    f"{getter}()", f"{getter}()", f"Get {doc}."))
        out.append((f"{qualified}:{setter}", "property",
                    f"{setter}({hint or 'value'})", f"{setter}(value)",
                    f"Set {doc}." + (f" One of: {hint}." if hint else "")))
        if alias:
            out.append((f"{qualified}:{alias}", "property",
                        f"{alias}()", f"{alias}()", f"Get {doc}."))

    for event in cls.__events__:
        setter = event.setter_name()
        out.append((f"{qualified}:{setter}", "event",
                    f"{setter}(function() end)", f"{setter}(handler)",
                    one_line(event.doc) or f"Attach a handler for {event.name}."))

    for info in introspect.public_methods(cls):
        arguments = params(info)
        # Static methods are called with a dot, instance methods with a colon.
        separator = "." if info.is_static else ":"
        out.append((f"{qualified}{separator}{info.name}", "method",
                    f"{info.name}({arguments})", f"{info.name}({arguments})",
                    one_line(info.doc) or f"{info.name} on {qualified}."))

    return out


def render():
    manifest.import_all()

    rows = []
    for module, members in sorted(registry.modules().items()):
        for name, cls in sorted(members.items()):
            rows.extend(entries_for(module, name, cls))

    lines = [
        "-- GENERATED by tools/generate_api_index.py -- do not edit by hand.",
        "--",
        "-- Every class, property, event and method Limekit exposes to Lua.",
        "-- Each row is { qualified, kind, snippet, signature, doc }.",
        "",
        "return {",
    ]
    for qualified, kind, snippet, signature, doc in rows:
        lines.append("    { %s, %s, %s, %s, %s }," % (
            quote(qualified), quote(kind), quote(snippet),
            quote(signature), quote(doc),
        ))
    lines.append("}")
    lines.append("")
    return "\n".join(lines), len(rows)


def main():
    text, count = render()
    if "--check" in sys.argv:
        current = TARGET.read_text(encoding="utf-8") if TARGET.exists() else ""
        if current != text:
            raise SystemExit(
                f"{TARGET.relative_to(LIMER)} is stale -- "
                "re-run tools/generate_api_index.py"
            )
        print(f"{TARGET.name} is up to date ({count} entries)")
        return
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {TARGET} ({count} entries)")


if __name__ == "__main__":
    main()
