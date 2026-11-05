#!/usr/bin/env python3
"""Check APK ZIP and 64-bit ELF segment alignment for 16 KB Android pages."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


PAGE_SIZE = 16 * 1024
ABIS = {"arm64-v8a", "x86_64"}


def find_sdk_tool(name, sdk):
    on_path = shutil.which(name)
    if on_path:
        return on_path
    if sdk:
        candidates = list(Path(sdk).glob(f"build-tools/*/{name}"))
        candidates += list(Path(sdk).glob(
            f"ndk/*/toolchains/llvm/prebuilt/*/bin/{name}"
        ))
        if candidates:
            return str(sorted(candidates)[-1])
    raise FileNotFoundError(f"{name} not found; set ANDROID_HOME or add it to PATH")


def segment_issues(output):
    segments = []
    for line in output.splitlines():
        fields = line.split()
        if fields and fields[0] in ("LOAD", "GNU_RELRO"):
            segments.append((fields[0], int(fields[2], 16), int(fields[5], 16),
                             "".join(fields[6:-1]), int(fields[-1], 16)))
    loads = [item for item in segments if item[0] == "LOAD"]
    if not loads:
        return ["no LOAD segments"]
    issues = []
    if any(alignment < PAGE_SIZE for _, _, _, _, alignment in loads):
        issues.append("LOAD alignment below 16 KB")
    for _, address, size, _, _ in (item for item in segments if item[0] == "GNU_RELRO"):
        end = address + size
        page_end = (end + PAGE_SIZE - 1) // PAGE_SIZE * PAGE_SIZE
        if page_end > end and any(
            "W" in flags and start < page_end and start + length > end
            for _, start, length, flags, _ in loads
        ):
            issues.append("writable LOAD shares the final RELRO page")
    return issues


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    args = parser.parse_args()
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    try:
        readelf = find_sdk_tool("llvm-readelf", sdk)
        zipalign = find_sdk_tool("zipalign", sdk)
        subprocess.run([zipalign, "-c", "-P", "16", "4", str(args.apk)], check=True)
        count = 0
        failed = False
        with zipfile.ZipFile(args.apk) as archive, tempfile.TemporaryDirectory() as temp:
            for name in sorted(archive.namelist()):
                parts = name.split("/")
                if len(parts) != 3 or parts[0] != "lib" or parts[1] not in ABIS or not name.endswith(".so"):
                    continue
                count += 1
                library = Path(temp) / f"{count}.so"
                library.write_bytes(archive.read(name))
                output = subprocess.check_output([readelf, "-Wl", str(library)], text=True)
                issues = segment_issues(output)
                print(f"{name}: {', '.join(issues) if issues else 'OK'}")
                failed |= bool(issues)
        if not count:
            raise ValueError("no supported 64-bit native libraries in APK")
        if failed:
            return 1
        print(f"APK ZIP alignment and {count} native libraries passed.")
        return 0
    except (OSError, ValueError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        print(f"16 KB check failed: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
