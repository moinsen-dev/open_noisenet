#!/usr/bin/env python3
"""Fixed AMI non-scenario excerpts: actual YAMNet inference, no audio playback.

Reads explicitly downloaded CC BY 4.0 corpus files outside the repository.
Only aggregate evidence goes into project documentation, never transcripts.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import xml.etree.ElementTree as ET
import zipfile

os.environ.update(TF_CPP_MIN_LOG_LEVEL="2", OMP_NUM_THREADS="2")


def union(parts):
    result = []
    for a, b in sorted(parts):
        if b <= a:
            continue
        if result and a <= result[-1][1]:
            result[-1][1] = max(result[-1][1], b)
        else:
            result.append([a, b])
    return result


def overlap(left, right):
    i = j = 0
    total = 0
    while i < len(left) and j < len(right):
        total += max(0, min(left[i][1], right[j][1]) - max(left[i][0], right[j][0]))
        if left[i][1] < right[j][1]:
            i += 1
        else:
            j += 1
    return total


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", type=Path, required=True)
    args = ap.parse_args()
    root = args.root
    repo = Path(__file__).resolve().parents[1]
    import numpy as np
    import soundfile as sf
    import tensorflow as tf

    plan = json.loads((root / "natural-scene-plan.json").read_text())
    manifest = json.loads((root / "natural-fixture-manifest.json").read_text())
    for row in manifest:
        if (
            hashlib.sha256((root / row["file"]).read_bytes()).hexdigest()
            != row["sha256"]
        ):
            raise ValueError("Fixture hash mismatch")
    annotations = zipfile.ZipFile(root / "ami_public_manual_1.6.2.zip")
    model = repo / "mobile/assets/models/yamnet.tflite"
    interpreter = tf.lite.Interpreter(model_path=str(model), num_threads=2)
    interpreter.allocate_tensors()
    inp, out = interpreter.get_input_details()[0], interpreter.get_output_details()[0]
    labels = (
        (repo / "mobile/assets/models/yamnet_label_list.txt").read_text().splitlines()
    )
    summary = []
    for scene in plan["scenes"]:
        meeting, channel = scene["meeting"], scene["channel"]
        name = f"{meeting}.{channel}"
        with sf.SoundFile(root / f"{name}.wav") as f:
            if f.samplerate != 16000:
                raise ValueError("Unexpected corpus sample rate")
            f.seek(scene["start_seconds"] * 16000)
            wave = f.read(scene["duration_seconds"] * 16000, dtype="float32")
        if wave.ndim > 1:
            wave = wave.mean(1)
        duration_ms = len(wave) // 16
        offset = scene["start_seconds"] * 1000
        reference = []
        speakers = 0
        for member in annotations.namelist():
            if (
                "/words/" not in "/" + member
                or not Path(member).name.startswith(meeting + ".")
                or not member.endswith(".words.xml")
            ):
                continue
            intervals = []
            for node in ET.fromstring(annotations.read(member)).iter():
                if (
                    node.tag.split("}")[-1] != "w"
                    or "starttime" not in node.attrib
                    or "endtime" not in node.attrib
                ):
                    continue
                # Consume only timing attributes; no transcript or speaker name
                # enters the result, feature cache or upload test.
                a = round(float(node.attrib["starttime"]) * 1000) - offset
                b = round(float(node.attrib["endtime"]) * 1000) - offset
                if min(b, duration_ms) > max(a, 0):
                    intervals.append([max(a, 0), min(b, duration_ms)])
            if intervals:
                speakers += 1
                reference.extend(intervals)
        reference = union(reference)
        if not reference:
            raise ValueError(f"Missing manual timing reference for {meeting}")
        frames = []
        elapsed = 0
        for t in range(0, len(wave) - 15600 + 1, 7680):
            start = time.monotonic()
            interpreter.set_tensor(
                inp["index"], wave[t : t + 15600].reshape(inp["shape"])
            )
            interpreter.invoke()
            scores = interpreter.get_tensor(out["index"]).reshape(-1)
            elapsed += time.monotonic() - start
            if not np.isfinite(scores).all():
                raise ValueError("Non-finite model output")
            frames.append(
                {
                    "start_ms": t // 16,
                    "end_ms": (t + 15600) // 16,
                    "yamnet": scores.tolist(),
                }
            )
        request = {
            "labels": labels,
            "include_frames": True,
            "scenes": [{"id": name, "frames": frames}],
        }
        result = json.loads(
            subprocess.run(
                ["dart", str(repo / "scripts/acoustic-phases.dart")],
                input=json.dumps(request),
                text=True,
                capture_output=True,
                check=True,
            ).stdout
        )["scenes"][0]
        (root / f"{name}.mapped-frames.json").write_text(
            json.dumps(
                {"id": name, "frames": result.pop("frames")}, separators=(",", ":")
            )
        )
        phases = [p for p in result["phases"] if p["family"] == "speech"]
        active = union(
            [
                [p["start_ms"], p["end_ms"]]
                for phase in phases
                for p in phase["activity"]
            ]
        )
        speech_ms = sum(b - a for a, b in reference)
        active_ms = sum(b - a for a, b in active)
        common = overlap(active, reference)
        natural_gap = max(
            (b[0] - a[1] for a, b in zip(reference, reference[1:])), default=0
        )
        summary.append(
            {
                "id": name,
                "original_start_seconds": scene["start_seconds"],
                "duration_ms": duration_ms,
                "inferred_windows": len(frames),
                "inference_seconds": elapsed,
                "speakers_with_annotations": speakers,
                "manual_word_activity_ms": speech_ms,
                "longest_word_free_gap_ms": natural_gap,
                "speech_phase_count": len(phases),
                "longest_phase_ms": max(
                    (p["end_ms"] - p["start_ms"] for p in phases), default=0
                ),
                "predicted_speech_activity_ms": active_ms,
                "word_time_recall": common / speech_ms,
                "word_time_precision": common / active_ms if active_ms else 0,
                "phases": result["phases"],
                "source_segment_count": result["source_segment_count"],
            }
        )
        print(
            name,
            "speech phases",
            len(phases),
            "longest",
            summary[-1]["longest_phase_ms"] / 1000,
            "word-time recall",
            round(common / speech_ms, 3),
            flush=True,
        )
    report = {
        "protocol": plan,
        "model_sha256": hashlib.sha256(model.read_bytes()).hexdigest(),
        "fixtures": manifest,
        "scenes": summary,
        "limitations": [
            "Real non-scenario English meetings, not a dwelling/TV/through-wall validation",
            "Manual word spans measure alignment, not complete acoustic speech or nuisance ground truth",
            "Close and far microphones of EN2002b share the same conversation; not independent scenes",
            "No parameters tuned on these scenes; no claim of common physical cause from temporal grouping",
        ],
    }
    (root / "natural-conversation-results.json").write_text(
        json.dumps(report, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
