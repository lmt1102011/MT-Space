#!/usr/bin/env python3
"""Puts the recorded pictures together as one looping animation.

Usage: python tools/makeanim.py <folder> <outfile> [fps] [loop]
"""

import os
import sys
import glob
import subprocess


def find_ffmpeg() -> str:
    for name in ("ffmpeg", "ffmpeg.exe"):
        try:
            subprocess.run([name, "-version"], capture_output=True, check=True)
            return name
        except (FileNotFoundError, subprocess.CalledProcessError):
            continue
    return ""


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    folder = sys.argv[1]
    outfile = sys.argv[2]
    fps = sys.argv[3] if len(sys.argv) > 3 else "12"
    loop = sys.argv[4] if len(sys.argv) > 4 else "0"

    frames = sorted(glob.glob(os.path.join(folder, "*.png")))
    if not frames:
        print("no pictures found in " + folder)
        return 1

    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        print("ffmpeg is needed to make the animation")
        return 1

    # the pictures are scaled down, that keeps the file small
    cmd = [
        ffmpeg, "-y", "-framerate", fps, "-start_number", "0",
        "-i", os.path.join(folder, "frame_%04d.png"),
        "-vf", "scale=640:-2:flags=lanczos,pad=ceil(iw/2)*2:ceil(ih/2)*2",
        "-c:v", "libwebp", "-lossless", "0", "-q:v", "72",
        "-loop", loop, "-an", outfile,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stderr[-800:])
        return 1
    print("wrote " + outfile + " (" + str(os.path.getsize(outfile) // 1024) + " kB, "
          + str(len(frames)) + " frames)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
