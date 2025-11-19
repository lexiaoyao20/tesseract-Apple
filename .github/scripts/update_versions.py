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
    print(f"Updated build.sh to version {version}")


def update_podspec_version_only(version: str, root: pathlib.Path) -> None:
    """Pre-build: Update only the version string in Podspec"""
    path = root / "Tesseract.podspec"
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8")

    # Update s.version
    def _repl_version(match: re.Match) -> str:
        return f"{match.group(1)}{version}{match.group(2)}"

    text, count = re.subn(
        r"(s\.version\s*=\s*['\"])[^'\"]+(['\"])",
        _repl_version,
        text,
    )
    path.write_text(text, encoding="utf-8")
    print(f"Updated Tesseract.podspec version to {version}")


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
    """Post-build: Update both Package.swift and Podspec to point to the Release Zip"""
    
    download_url = f"https://github.com/{repo}/releases/download/{version}/Tesseract.xcframework.zip"
    
    # 1. Update Package.swift (binaryTarget url & checksum)
    pkg_path = root / "Package.swift"
    if pkg_path.is_file():
        pkg_text = pkg_path.read_text(encoding="utf-8")
        
        # Replace url
        pkg_text = re.sub(
            r'(url:\s*")[^"]+(")',
            f'\\g<1>{download_url}\\g<2>', # 使用 \\g<1> 避免歧义
            pkg_text
        )
        
        if "path:" in pkg_text and "binaryTarget" in pkg_text:
             # Replace path: "..." with url: "...", checksum: "..."
             pkg_text = re.sub(
                r'path:\s*"[^"]+"',
                f'url: "{download_url}",\n            checksum: "{checksum}"',
                pkg_text
             )
        else:
             # Just update checksum if it already exists
             pkg_text = re.sub(
                r'(checksum:\s*")[^"]+(")',
                f'\\g<1>{checksum}\\g<2>', # 使用 \\g<1> 修复 Invalid group reference 错误
                pkg_text
             )
        
        pkg_path.write_text(pkg_text, encoding="utf-8")
        print(f"Updated Package.swift with URL and Checksum")

    # 2. Update Tesseract.podspec (s.source to http)
    pod_path = root / "Tesseract.podspec"
    if pod_path.is_file():
        pod_text = pod_path.read_text(encoding="utf-8")
        
        new_source = f"s.source           = {{ :http => '{download_url}' }}"
        
        pod_text = re.sub(
            r"s\.source\s*=\s*\{.*?\}",
            new_source,
            pod_text,
            flags=re.DOTALL
        )
        
        pod_path.write_text(pod_text, encoding="utf-8")
        print(f"Updated Tesseract.podspec source to HTTP Release URL")


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
        update_podspec_version_only(version, root)
        update_package_swift_version_comment(version, root)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())