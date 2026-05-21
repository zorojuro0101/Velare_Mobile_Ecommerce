"""Bulk-refactor Flutter Dart files para gumamit ng flutter_screenutil.

Transformations:
- fontSize: <num>            -> fontSize: <num>.sp
- EdgeInsets.all(N)          -> EdgeInsets.all(N.w)
- EdgeInsets.symmetric(...)  -> vertical->.h, horizontal->.w
- EdgeInsets.only(...)       -> top/bottom->.h, left/right->.w
- EdgeInsets.fromLTRB(L,T,R,B) -> .w, .h, .w, .h
- SizedBox(width: X)         -> .w
- SizedBox(height: Y)        -> .h
- SizedBox.square(dimension: X) -> .w
- BorderRadius.circular(X)   -> .r
- Radius.circular(X)         -> .r
- Container(width: X, height: Y) -> .w / .h
- Icon(... size: X)          -> .r
- iconSize: X                -> .r
- letterSpacing: X           -> .sp
- Adds flutter_screenutil import if missing
- Removes invalid `const` keywords (where args become non-const)

Usage:
    python tools/refactor_responsive.py
"""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parent.parent
LIB_DIR = ROOT / "lib"

# Files we should NOT touch (already responsive or shouldn't be modified)
SKIP_FILES = {
    LIB_DIR / "main.dart",
    LIB_DIR / "utils" / "font_helper.dart",
    LIB_DIR / "utils" / "responsive_helper.dart",
}

# Suffixes from flutter_screenutil
SU_SUFFIXES = (".sp", ".w", ".h", ".r", ".sw", ".sh", ".dm")

IMPORT_LINE = "import 'package:flutter_screenutil/flutter_screenutil.dart';"

NUMBER = r"(-?\d+(?:\.\d+)?)"


# ---------------------------------------------------------------------------
# Helpers for skipping strings/comments while doing regex-style transformations
# ---------------------------------------------------------------------------
def _mask_strings_and_comments(text: str) -> tuple[str, list[tuple[int, int, str]]]:
    """Replace string-literal and comment regions with placeholders so regex
    transforms don't accidentally modify literals/comments.
    Returns the masked text + list of (start, end, original) for restoration.
    """
    spans: list[tuple[int, int, str]] = []
    masked = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        # Line comment
        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            if j == -1:
                j = n
            spans.append((i, j, text[i:j]))
            masked.append("\0" * (j - i))
            i = j
            continue
        # Block comment
        if ch == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            if j == -1:
                j = n
            else:
                j += 2
            spans.append((i, j, text[i:j]))
            masked.append("\0" * (j - i))
            i = j
            continue
        # Triple-quoted string
        if ch in "\"'" and i + 2 < n and text[i + 1] == ch and text[i + 2] == ch:
            quote = ch * 3
            j = text.find(quote, i + 3)
            if j == -1:
                j = n
            else:
                j += 3
            spans.append((i, j, text[i:j]))
            masked.append("\0" * (j - i))
            i = j
            continue
        # Single-line string (handles escapes)
        if ch in "\"'":
            quote = ch
            j = i + 1
            while j < n:
                if text[j] == "\\" and j + 1 < n:
                    j += 2
                    continue
                if text[j] == quote:
                    j += 1
                    break
                if text[j] == "\n":  # unterminated -- bail
                    break
                j += 1
            spans.append((i, j, text[i:j]))
            masked.append("\0" * (j - i))
            i = j
            continue
        masked.append(ch)
        i += 1
    return "".join(masked), spans


def _restore_masked(masked_text: str, original: str) -> str:
    """Restore string/comment regions to a (possibly modified) masked text.
    Assumption: transformations preserve length-equality of masked spans.
    """
    # Re-mask, then merge: any '\0' run in `masked_text` is replaced with the
    # corresponding original substring positionally. To stay safe, we assume
    # positions are stable (we don't insert/delete characters inside masked
    # spans, only outside them). After our transforms, lengths can change, so
    # we use a different strategy: mask original, run transforms on masked
    # version, then restore by walking original spans.
    raise NotImplementedError


def _safe_sub(pattern: re.Pattern[str] | str, repl, text: str) -> str:
    """Apply a regex substitution, but skip matches that fall inside string
    literals or comments."""
    masked, _ = _mask_strings_and_comments(text)

    if isinstance(pattern, str):
        pattern = re.compile(pattern, flags=re.DOTALL)

    out_parts: list[str] = []
    last = 0
    for m in pattern.finditer(masked):
        if "\0" in masked[m.start():m.end()]:
            continue  # match overlaps a masked span
        out_parts.append(text[last:m.start()])
        new_segment = m.expand(repl) if isinstance(repl, str) else repl(m)
        out_parts.append(new_segment)
        last = m.end()
    out_parts.append(text[last:])
    return "".join(out_parts)


def _suffix_already(num_str: str, after: str) -> bool:
    """Return True kung yung number ay sinusundan na ng known screenutil suffix."""
    for s in SU_SUFFIXES:
        if after.startswith(s):
            return True
    return False


def _add_suffix(num_str: str, suffix: str) -> str:
    """Append suffix to a number literal, handling integer→double conversion."""
    if "." in num_str:
        return f"{num_str}{suffix}"
    # Integer: int doesn't have .sp/.w/.h, but flutter_screenutil's extensions
    # are on `num`, so 16.sp works (Dart resolves on num). Just append.
    return f"{num_str}{suffix}"


# ---------------------------------------------------------------------------
# Individual transformations
# ---------------------------------------------------------------------------
def transform_font_size(text: str) -> str:
    """fontSize: X  ->  fontSize: X.sp"""
    pat = re.compile(r"\bfontSize:\s*" + NUMBER + r"(?![\.\w])")
    def repl(m):
        return f"fontSize: {_add_suffix(m.group(1), '.sp')}"
    return _safe_sub(pat, repl, text)


def transform_letter_spacing(text: str) -> str:
    pat = re.compile(r"\bletterSpacing:\s*" + NUMBER + r"(?![\.\w])")
    return _safe_sub(pat, lambda m: f"letterSpacing: {_add_suffix(m.group(1), '.sp')}", text)


def transform_height_text(text: str) -> str:
    """height: X within TextStyle context — skip for safety (height is a
    multiplier, dimensionless)."""
    return text


def transform_edge_insets_all(text: str) -> str:
    """EdgeInsets.all(N) -> EdgeInsets.all(N.w)"""
    pat = re.compile(r"\bEdgeInsets\.all\(\s*" + NUMBER + r"\s*\)")
    def repl(m):
        return f"EdgeInsets.all({_add_suffix(m.group(1), '.w')})"
    return _safe_sub(pat, repl, text)


def transform_edge_insets_symmetric(text: str) -> str:
    """EdgeInsets.symmetric(vertical: V, horizontal: H) — V→.h, H→.w."""
    # Match the EdgeInsets.symmetric(...) call with up to two named args.
    pat = re.compile(
        r"\bEdgeInsets\.symmetric\(([^()]*)\)"
    )
    def repl(m):
        body = m.group(1)
        new_body = re.sub(
            r"\bvertical:\s*" + NUMBER + r"(?![\.\w])",
            lambda mm: f"vertical: {_add_suffix(mm.group(1), '.h')}",
            body,
        )
        new_body = re.sub(
            r"\bhorizontal:\s*" + NUMBER + r"(?![\.\w])",
            lambda mm: f"horizontal: {_add_suffix(mm.group(1), '.w')}",
            new_body,
        )
        return f"EdgeInsets.symmetric({new_body})"
    return _safe_sub(pat, repl, text)


def transform_edge_insets_only(text: str) -> str:
    """EdgeInsets.only(top: T, bottom: B, left: L, right: R)."""
    pat = re.compile(r"\bEdgeInsets\.only\(([^()]*)\)")
    def repl(m):
        body = m.group(1)
        new_body = body
        for key, suffix in (("top", ".h"), ("bottom", ".h"), ("left", ".w"), ("right", ".w")):
            new_body = re.sub(
                rf"\b{key}:\s*" + NUMBER + r"(?![\.\w])",
                lambda mm, k=key, s=suffix: f"{k}: {_add_suffix(mm.group(1), s)}",
                new_body,
            )
        return f"EdgeInsets.only({new_body})"
    return _safe_sub(pat, repl, text)


def transform_edge_insets_from_ltrb(text: str) -> str:
    """EdgeInsets.fromLTRB(L, T, R, B) -> .w, .h, .w, .h"""
    pat = re.compile(
        r"\bEdgeInsets\.fromLTRB\(\s*"
        + NUMBER + r"\s*,\s*"
        + NUMBER + r"\s*,\s*"
        + NUMBER + r"\s*,\s*"
        + NUMBER + r"\s*\)"
    )
    def repl(m):
        l, t, r, b = m.group(1), m.group(2), m.group(3), m.group(4)
        return (
            f"EdgeInsets.fromLTRB("
            f"{_add_suffix(l, '.w')}, "
            f"{_add_suffix(t, '.h')}, "
            f"{_add_suffix(r, '.w')}, "
            f"{_add_suffix(b, '.h')})"
        )
    return _safe_sub(pat, repl, text)


def transform_sized_box(text: str) -> str:
    """SizedBox(width: X, height: Y) and SizedBox.square(dimension: X)."""
    # height
    text = _safe_sub(
        re.compile(r"(SizedBox\([^()]*\bheight:\s*)" + NUMBER + r"(?![\.\w])"),
        lambda m: m.group(1) + _add_suffix(m.group(2), ".h"),
        text,
    )
    # width
    text = _safe_sub(
        re.compile(r"(SizedBox\([^()]*\bwidth:\s*)" + NUMBER + r"(?![\.\w])"),
        lambda m: m.group(1) + _add_suffix(m.group(2), ".w"),
        text,
    )
    # dimension (square)
    text = _safe_sub(
        re.compile(r"(SizedBox\.square\([^()]*\bdimension:\s*)" + NUMBER + r"(?![\.\w])"),
        lambda m: m.group(1) + _add_suffix(m.group(2), ".w"),
        text,
    )
    return text


def transform_border_radius(text: str) -> str:
    """BorderRadius.circular(X) and Radius.circular(X) -> .r"""
    text = _safe_sub(
        re.compile(r"BorderRadius\.circular\(\s*" + NUMBER + r"\s*\)"),
        lambda m: f"BorderRadius.circular({_add_suffix(m.group(1), '.r')})",
        text,
    )
    text = _safe_sub(
        re.compile(r"Radius\.circular\(\s*" + NUMBER + r"\s*\)"),
        lambda m: f"Radius.circular({_add_suffix(m.group(1), '.r')})",
        text,
    )
    return text


def transform_icon_size(text: str) -> str:
    """Icon(..., size: X) and iconSize: X (named param) -> .r"""
    # iconSize:
    text = _safe_sub(
        re.compile(r"\biconSize:\s*" + NUMBER + r"(?![\.\w])"),
        lambda m: f"iconSize: {_add_suffix(m.group(1), '.r')}",
        text,
    )
    # size: inside Icon(...) — we approximate with a non-greedy pattern
    text = _safe_sub(
        re.compile(r"(Icon\((?:[^()]|\([^()]*\))*?\bsize:\s*)" + NUMBER + r"(?![\.\w])"),
        lambda m: m.group(1) + _add_suffix(m.group(2), ".r"),
        text,
    )
    return text


def transform_container_dims(text: str) -> str:
    """Container(width: X, height: Y) -> .w / .h.

    Also handles Container.fromLTRB-like patterns. We constrain to widgets that
    typically have width/height: Container, SizedBox (already handled), CircleAvatar (radius).
    To stay safe, we only target Container here.
    """
    text = _safe_sub(
        re.compile(r"(Container\((?:[^()]|\([^()]*\))*?\bwidth:\s*)" + NUMBER + r"(?![\.\w])"),
        lambda m: m.group(1) + _add_suffix(m.group(2), ".w"),
        text,
    )
    text = _safe_sub(
        re.compile(r"(Container\((?:[^()]|\([^()]*\))*?\bheight:\s*)" + NUMBER + r"(?![\.\w])"),
        lambda m: m.group(1) + _add_suffix(m.group(2), ".h"),
        text,
    )
    return text


def transform_circle_avatar_radius(text: str) -> str:
    """CircleAvatar(radius: X) -> .r"""
    return _safe_sub(
        re.compile(r"(CircleAvatar\((?:[^()]|\([^()]*\))*?\bradius:\s*)" + NUMBER + r"(?![\.\w])"),
        lambda m: m.group(1) + _add_suffix(m.group(2), ".r"),
        text,
    )


def transform_text_field_strut(text: str) -> str:
    """height: X for SizedBox/Container handled. Skip TextStyle.height which is
    a unitless multiplier.
    """
    return text


# ---------------------------------------------------------------------------
# const removal — uses bracket matching to find expressions whose contents now
# contain non-const screenutil suffixes, and strips the leading `const`.
# ---------------------------------------------------------------------------
_CONST_KEYWORD_RE = re.compile(r"\bconst\b")
_IDENT_RE = re.compile(r"[A-Za-z_][\w$.]*")
_OPEN_TO_CLOSE = {"(": ")", "[": "]", "{": "}"}


def _find_expression_end(text: str, start: int) -> int:
    """Given a position pointing at '(' / '[' / '{', return the index AFTER the
    matching closing bracket. Skips strings and comments."""
    n = len(text)
    if start >= n or text[start] not in _OPEN_TO_CLOSE:
        return start
    stack = [text[start]]
    i = start + 1
    while i < n and stack:
        ch = text[i]
        # Skip line comment
        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            i = n if j == -1 else j
            continue
        # Skip block comment
        if ch == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            i = n if j == -1 else j + 2
            continue
        # Skip triple-quoted string
        if ch in "\"'" and i + 2 < n and text[i + 1] == ch and text[i + 2] == ch:
            quote = ch * 3
            j = text.find(quote, i + 3)
            i = n if j == -1 else j + 3
            continue
        # Skip regular string
        if ch in "\"'":
            quote = ch
            j = i + 1
            while j < n:
                if text[j] == "\\" and j + 1 < n:
                    j += 2
                    continue
                if text[j] == quote:
                    j += 1
                    break
                if text[j] == "\n":
                    break
                j += 1
            i = j
            continue
        if ch in _OPEN_TO_CLOSE:
            stack.append(ch)
        elif ch in (")", "]", "}"):
            if stack and _OPEN_TO_CLOSE[stack[-1]] == ch:
                stack.pop()
            else:
                return i  # mismatch — bail
        i += 1
    return i


def _expression_contains_su_suffix(text: str, start: int, end: int) -> bool:
    """Check whether the expression substring contains a screenutil suffix
    OUTSIDE strings/comments."""
    masked, _ = _mask_strings_and_comments(text[start:end])
    for s in SU_SUFFIXES:
        # Find suffix not part of a longer identifier
        for m in re.finditer(re.escape(s) + r"(?![A-Za-z_])", masked):
            # Make sure it's preceded by a digit or closing-paren (i.e. attached
            # to a number/expression). Avoid matching e.g. `.sample`.
            prev_idx = m.start() - 1
            if prev_idx < 0:
                continue
            prev_ch = masked[prev_idx]
            if prev_ch.isdigit() or prev_ch == ')':
                return True
    return False


def remove_invalid_const(text: str) -> str:
    """Find every `const` keyword whose attached expression contains a
    screenutil suffix and remove it.
    """
    masked, _ = _mask_strings_and_comments(text)
    # We mutate the original `text` from right to left so indices stay valid.
    matches = list(_CONST_KEYWORD_RE.finditer(masked))
    matches.reverse()

    # We also need to track outer const's that wrap collection/widget literals
    # whose interior elements have become non-const. Easier: do a second pass.

    for m in matches:
        cstart, cend = m.start(), m.end()
        # Skip occurrences inside strings/comments — already handled by mask
        if "\0" in masked[cstart:cend]:
            continue
        # Look at what follows `const` to decide where the expression ends.
        i = cend
        n = len(text)
        while i < n and text[i].isspace():
            i += 1
        if i >= n:
            continue
        ch = text[i]
        expr_end = i
        if ch in "([{":
            expr_end = _find_expression_end(text, i)
        else:
            # Maybe an identifier (constructor) followed by '(' or '<'
            ident_match = _IDENT_RE.match(text, i)
            if not ident_match:
                continue
            j = ident_match.end()
            # Skip generic type args: <...>
            if j < n and text[j] == "<":
                # Find matching '>'
                depth = 1
                k = j + 1
                while k < n and depth:
                    cc = text[k]
                    if cc == "<":
                        depth += 1
                    elif cc == ">":
                        depth -= 1
                    elif cc in "({[\"'":
                        # bail on complex generics (rare)
                        break
                    k += 1
                if depth == 0:
                    j = k
            # Skip whitespace then expect '('
            while j < n and text[j].isspace():
                j += 1
            if j >= n or text[j] not in "([{":
                continue
            expr_end = _find_expression_end(text, j)

        # Now expr spans [cstart, expr_end). Check for screenutil suffix.
        if _expression_contains_su_suffix(text, cstart, expr_end):
            # Remove the `const` keyword + one trailing space
            remove_end = cend
            if remove_end < n and text[remove_end] == " ":
                remove_end += 1
            text = text[:cstart] + text[remove_end:]
            # Update masked accordingly
            masked = masked[:cstart] + masked[remove_end:]
    return text


# ---------------------------------------------------------------------------
# Add screenutil import
# ---------------------------------------------------------------------------
def ensure_screenutil_import(text: str) -> str:
    if "package:flutter_screenutil/flutter_screenutil.dart" in text:
        return text
    # Insert after the last existing import statement
    lines = text.splitlines(keepends=True)
    last_import_idx = -1
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("import ") and stripped.endswith(";"):
            last_import_idx = idx
    if last_import_idx == -1:
        # No imports — insert at top after any leading comment block
        lines.insert(0, IMPORT_LINE + "\n")
    else:
        lines.insert(last_import_idx + 1, IMPORT_LINE + "\n")
    return "".join(lines)


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------
def process_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    text = original

    text = transform_font_size(text)
    text = transform_letter_spacing(text)
    text = transform_edge_insets_all(text)
    text = transform_edge_insets_symmetric(text)
    text = transform_edge_insets_only(text)
    text = transform_edge_insets_from_ltrb(text)
    text = transform_sized_box(text)
    text = transform_border_radius(text)
    text = transform_icon_size(text)
    text = transform_container_dims(text)
    text = transform_circle_avatar_radius(text)

    if text != original:
        text = ensure_screenutil_import(text)
        # Run const removal multiple times until stable (handles nested wrappers)
        for _ in range(5):
            new_text = remove_invalid_const(text)
            if new_text == text:
                break
            text = new_text

    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def iter_dart_files(root: Path) -> Iterable[Path]:
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if name.endswith(".dart"):
                p = Path(dirpath) / name
                if p.resolve() in {f.resolve() for f in SKIP_FILES}:
                    continue
                yield p


def main():
    changed = []
    skipped = 0
    for p in iter_dart_files(LIB_DIR):
        try:
            if process_file(p):
                changed.append(p.relative_to(ROOT))
            else:
                skipped += 1
        except Exception as e:
            print(f"[ERROR] {p}: {e}")
    print(f"Changed: {len(changed)} files, skipped: {skipped}")
    for c in changed:
        print(f"  - {c}")


if __name__ == "__main__":
    main()
