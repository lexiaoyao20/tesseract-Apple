#!/usr/bin/env python3

import os
import pathlib
import re
import sys


def update_build_sh(version: str, root: pathlib.Path) -> None:
    path = root / "build.sh"
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8")

    def _repl(match: re.Match) -> str:
        return f'{match.group(1)}{version}{match.group(2)}'

    new_text, count = re.subn(
        r'(TESSERACT_VERSION="\${TESSERACT_VERSION:-)[^"]+("})',
        _repl,
        text,
    )
    if count:
        path.write_text(new_text, encoding="utf-8")


def update_podspec(version: str, repo: str, root: pathlib.Path) -> None:
    path = root / "Tesseract.podspec"
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8")

    # Update s.version
    def _repl_version(match: re.Match) -> str:
        return f"{match.group(1)}{version}{match.group(2)}"

    text, _ = re.subn(
        r"(s\.version\s*=\s*['\"])[^'\"]+(['\"])",
        _repl_version,
        text,
    )

    # Update s.source git URL to current GitHub repository
    if repo:
        url = f"https://github.com/{repo}.git"
        def _replace_source_line(line: str) -> str:
            if "s.source" not in line or ":git" not in line:
                return line
            return re.sub(
                r"(s\.source\s*=\s*\{\s*:git\s*=>\s*['\"])[^'\"]+",
                lambda match: f"{match.group(1)}{url}",
                line,
            )

        lines = [ _replace_source_line(l) for l in text.splitlines() ]
        text = "\n".join(lines)

    path.write_text(text, encoding="utf-8")


def update_package_swift(version: str, root: pathlib.Path) -> None:
    path = root / "Package.swift"
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8")
    def _repl_comment(match: re.Match) -> str:
        return f"{match.group(1)}{version}"

    new_text, count = re.subn(
        r"(// Upstream Tesseract OCR version:\s*)[0-9A-Za-z._-]+",
        _repl_comment,
        text,
    )
    if count:
        path.write_text(new_text, encoding="utf-8")


def main() -> int:
    version = os.environ.get("LATEST_TESS_VERSION")
    if not version:
        print("LATEST_TESS_VERSION environment variable is required", file=sys.stderr)
        return 1

    repo = os.environ.get("GITHUB_REPOSITORY", "")
    root = pathlib.Path(__file__).resolve().parents[2]

    update_build_sh(version, root)
    update_podspec(version, repo, root)
    update_package_swift(version, root)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
