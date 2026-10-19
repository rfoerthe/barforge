#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Roland Foerther

"""Shows the fork's own name wherever the app shows its name to people.

Upstream text names the app "Vorssaint", a name this fork may not use (see
TRADEMARKS.md). The script rewrites that name to "Barforge" inside string
literals only: Swift sources and tests, Info.plist and the InfoPlist.strings
files. Everything that is not shown to people stays as upstream wrote it, so
merges stay small:

- comments, copyright headers and code identifiers (hideVorssaintWindows,
  the Sources/Vorssaint module folder, com.vorssaint.* identifiers)
- upstream's earlier app name "Vorssaint Utils", which still names old bundles
- the files in KEEP_FILES, whose strings mean upstream's app on purpose

Run it again after every merge from upstream. With --check it changes
nothing and fails while any string still shows the old name.

    python3 Tools/fork-rebrand.py          # rewrite
    python3 Tools/fork-rebrand.py --check  # verify, for CI and before a commit
"""

import pathlib
import re
import sys

OLD = "Vorssaint"
NEW = "Barforge"
ROOT = pathlib.Path(__file__).resolve().parent.parent

# Strings in these files name upstream's own app on purpose.
KEEP_FILES = {
    "Sources/Vorssaint/Core/BundleMigration.swift",
    # Names upstream as the copyright holder and the original project.
    "Sources/Vorssaint/Core/AppInfo.swift",
    "Sources/Vorssaint/Core/ForkBuildStrings.swift",
    "Tests/ForkBuildTests.swift",
}

# Forms where the name is inflected or carries a suffix. Barforge does not
# decline like Vorssaint, so these are rewritten as whole phrases first.
PHRASES = [
    # Slovak: "Barforge" stays undeclined, the noun "aplikácia" declines.
    ("vo Vorssainte", "v aplikácii Barforge"),
    ("nedovolil Vorssaintu", "nedovolil aplikácii Barforge"),
    ("ste Vorssaintu udelili", "ste aplikácii Barforge udelili"),
    ("Pomôžte Vorssaintu", "Pomôžte aplikácii Barforge"),
    ("Dajte Vorssaintu", "Dajte aplikácii Barforge"),
    ("Vorssaintu", "aplikácie Barforge"),
    # German genitive.
    ("Vorssaints", "Barforges"),
    # Turkish case suffixes follow how "Barforge" is said ("barforc").
    ("Vorssaint’ın", "Barforge’un"),
    ("Vorssaint’in", "Barforge’un"),
    ("Vorssaint’i", "Barforge’u"),
    ("Vorssaint’e", "Barforge’a"),
    ("Vorssaint’ten", "Barforge’dan"),
    ("Vorssaint’ta", "Barforge’da"),
    # Korean particles: "Barforge" ends in a vowel when read out.
    ("Vorssaint은", "Barforge는"),
    ("Vorssaint이", "Barforge가"),
    ("Vorssaint을", "Barforge를"),
    ("Vorssaint과", "Barforge와"),
]

# The bare name, not inside an identifier or a path. ASCII classes on purpose:
# Japanese, Chinese and Korean text runs straight into the name.
NAME = re.compile(r"(?<![A-Za-z0-9_/])" + OLD + r"(?![A-Za-z0-9_/])")
LEGACY = OLD + " Utils"
PLACEHOLDER = "\0LEGACY\0"


def rebrand(text):
    text = text.replace(LEGACY, PLACEHOLDER)
    for old, new in PHRASES:
        text = text.replace(old, new)
    text = NAME.sub(NEW, text)
    return text.replace(PLACEHOLDER, LEGACY)


def leftovers(text):
    return NAME.findall(text.replace(LEGACY, PLACEHOLDER))


QUOTE = re.compile(r'(#*)("""|")')


def swift_string_spans(src):
    """The (start, end) ranges of literal text in Swift string literals,
    without interpolated code, comments or anything outside strings."""
    spans = []
    stack = [["code", 0, False]]  # code frames: paren depth, inside \( )
    i, n = 0, len(src)
    while i < n:
        top = stack[-1]
        if top[0] == "code":
            if src.startswith("//", i):
                end = src.find("\n", i)
                i = n if end < 0 else end
                continue
            if src.startswith("/*", i):
                depth, i = 1, i + 2
                while i < n and depth:
                    if src.startswith("/*", i):
                        depth, i = depth + 1, i + 2
                    elif src.startswith("*/", i):
                        depth, i = depth - 1, i + 2
                    else:
                        i += 1
                continue
            m = QUOTE.match(src, i)
            if m:
                stack.append(["str", m.group(2), len(m.group(1)), m.end()])
                i = m.end()
                continue
            c = src[i]
            if c == "(":
                top[1] += 1
            elif c == ")":
                if top[2] and top[1] == 0:
                    stack.pop()
                    stack[-1][3] = i + 1
                    i += 1
                    continue
                top[1] -= 1
            i += 1
        else:
            _, quote, hashes, start = top
            closing = quote + "#" * hashes
            if src.startswith(closing, i):
                spans.append((start, i))
                stack.pop()
                i += len(closing)
                continue
            escape = "\\" + "#" * hashes
            if src.startswith(escape, i):
                after = i + len(escape)
                if after < n and src[after] == "(":
                    spans.append((start, i))
                    stack.append(["code", 0, True])
                    i = after + 1
                else:
                    i = after + 1
                continue
            i += 1
    return spans


def process_swift(src):
    out, problems, last = [], [], 0
    for start, end in swift_string_spans(src):
        out.append(src[last:start])
        piece = src[start:end]
        out.append(rebrand(piece))
        if leftovers(rebrand(piece)):
            problems.append(src.count("\n", 0, start) + 1)
        last = end
    out.append(src[last:])
    return "".join(out), problems


def process_lines(src):
    """Info.plist and .strings: every line but a copyright notice."""
    lines = src.splitlines(keepends=True)
    out = [line if "Copyright" in line or "©" in line else rebrand(line) for line in lines]
    return "".join(out), []


def targets():
    for base in ("Sources", "Tests"):
        yield from sorted((ROOT / base).rglob("*.swift"))
    yield ROOT / "Resources/Info.plist"
    yield from sorted((ROOT / "Resources").glob("*.lproj/*.strings"))


def main(argv):
    check = "--check" in argv
    changed, failed = [], []
    for path in targets():
        rel = path.relative_to(ROOT).as_posix()
        if rel in KEEP_FILES:
            continue
        src = path.read_text(encoding="utf-8")
        new, problems = (process_swift if path.suffix == ".swift" else process_lines)(src)
        failed += [f"{rel}:{line}" for line in problems]
        if new != src:
            changed.append(rel)
            if not check:
                path.write_text(new, encoding="utf-8")
    if failed:
        print(f"Strings that still show {OLD} after rewriting:", *failed, sep="\n  ")
    if check:
        if changed:
            print(f"Strings still show {OLD}; run Tools/fork-rebrand.py:", *changed, sep="\n  ")
        return 1 if changed or failed else 0
    print(f"Rewrote {len(changed)} files.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
