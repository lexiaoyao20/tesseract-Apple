#!/usr/bin/env python3

import os
import pathlib
import re
import sys
import argparse


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

    # Update s.source git URL
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


def update_package_swift_version(version: str, root: pathlib.Path) -> None:
    """Update the version comment in Package.swift (Pre-build)"""
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


def update_package_swift_checksum(version: str, repo: str, checksum: str, root: pathlib.Path) -> None:
    """Update the binaryTarget url and checksum in Package.swift (Post-build)"""
    path = root / "Package.swift"
    if not path.is_file():
        print(f"Warning: {path} not found", file=sys.stderr)
        return
        
    text = path.read_text(encoding="utf-8")
    
    # Construct the release URL
    # e.g. https://github.com/user/repo/releases/download/5.5.0/Tesseract.xcframework.zip
    download_url = f"https://github.com/{repo}/releases/download/{version}/Tesseract.xcframework.zip"
    
    # Regex to find binaryTarget. 
    # Matches: .binaryTarget(name: "Tesseract", url: "...", checksum: "...")
    # This is a simplified regex, assuming standard formatting.
    
    # 1. Replace URL
    text = re.sub(
        r'(url:\s*")[^"]+(")',
        f'\\1{download_url}\\2',
        text
    )
    
    # 2. Replace Checksum
    text = re.sub(
        r'(checksum:\s*")[^"]+(")',
        f'\\1{checksum}\\2',
        text
    )
    
    path.write_text(text, encoding="utf-8")
    print(f"Updated Package.swift with checksum: {checksum}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checksum", help="The SHA256 checksum of the zip file (triggers post-build update)")
    args = parser.parse_args()

    version = os.environ.get("LATEST_TESS_VERSION")
    if not version:
        print("LATEST_TESS_VERSION environment variable is required", file=sys.stderr)
        return 1

    repo = os.environ.get("GITHUB_REPOSITORY", "")
    root = pathlib.Path(__file__).resolve().parents[2]

    if args.checksum:
        # Post-build: Update Package.swift with checksum
        if not repo:
             print("GITHUB_REPOSITORY environment variable is required for checksum update", file=sys.stderr)
             return 1
        update_package_swift_checksum(version, repo, args.checksum, root)
    else:
        # Pre-build: Update versions in scripts and podspec
        update_build_sh(version, root)
        update_podspec(version, repo, root)
        update_package_swift_version(version, root)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())