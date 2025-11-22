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
        return f"{match.group(1)}{version}{match.group(2)}"

    new_text, count = re.subn(
        r'(TESSERACT_VERSION="\${TESSERACT_VERSION:-)[^"]+("})',
        _repl,
        text,
    )
    if count:
        path.write_text(new_text, encoding="utf-8")
    print(f"Updated build.sh to version {version}")


def update_package_swift_version_comment(version: str, root: pathlib.Path) -> None:
    """Pre-build: Update the version comment in Package.swift"""
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
    print(f"Updated Package.swift version comment to {version}")


def update_dependencies_to_binary_release(version: str, repo: str, checksum: str, root: pathlib.Path) -> None:
    """Post-build: Update Package.swift to point to the Release Zip"""

    download_url = f"https://github.com/{repo}/releases/download/{version}/Tesseract.xcframework.zip"

    pkg_path = root / "Package.swift"
    if pkg_path.is_file():
        pkg_text = pkg_path.read_text(encoding="utf-8")

        # Only update the binary target for the prebuilt XCFramework.
        pkg_text, url_replaced = re.subn(
            r'(\.binaryTarget\s*\(\s*name:\s*"Tesseract"[^)]*url:\s*")[^"]+(")',
            f"\\g<1>{download_url}\\g<2>",
            pkg_text,
            flags=re.DOTALL,
        )

        pkg_text, checksum_replaced = re.subn(
            r'(\.binaryTarget\s*\(\s*name:\s*"Tesseract"[^)]*checksum:\s*")[^"]+(")',
            f"\\g<1>{checksum}\\g<2>",
            pkg_text,
            flags=re.DOTALL,
        )

        if not url_replaced or not checksum_replaced:
            print("Warning: failed to update binary target URL or checksum in Package.swift", file=sys.stderr)

        pkg_path.write_text(pkg_text, encoding="utf-8")
        print("Updated Package.swift binary target with URL and checksum")


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
        # Post-build Phase: Update dependencies to point to the remote binary
        if not repo:
            print("GITHUB_REPOSITORY environment variable is required for checksum update", file=sys.stderr)
            return 1
        update_dependencies_to_binary_release(version, repo, args.checksum, root)
    else:
        # Pre-build Phase: Update version numbers in text
        update_build_sh(version, root)
        update_package_swift_version_comment(version, root)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
