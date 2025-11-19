#!/usr/bin/env python3

import re
import subprocess
import sys


def main() -> int:
    try:
        # 防止 CI 环境 Token 干扰，强制使用匿名访问
        out = subprocess.check_output(
            ["git", "-c", "http.extraheader=", "ls-remote", "--tags", "https://github.com/tesseract-ocr/tesseract.git"],
            text=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"Failed to list remote tags: {e}", file=sys.stderr)
        return 1

    versions = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        ref = parts[1]
        if not ref.startswith("refs/tags/"):
            continue
        tag = ref[len("refs/tags/"):]
        if tag.endswith("^{}"):
            tag = tag[:-3]
        # 只考虑纯数字版本，如 5.5.1 或 4.1
        if not re.fullmatch(r"\d+(?:\.\d+)*", tag):
            continue
        versions.append(tuple(int(x) for x in tag.split(".")))

    if not versions:
        print("No numeric version tags found on upstream tesseract repo", file=sys.stderr)
        return 1

    max_version = max(versions)
    print(".".join(str(x) for x in max_version))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())