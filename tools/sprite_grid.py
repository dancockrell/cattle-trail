"""Reusable magenta-sheet extraction; importing this module writes nothing.

Dependencies: Pillow, numpy, scipy. No resizing, pose labels or visual admission.
The default 4x4 grid and five-pixel speck filter match extract_kits.py for
opaque magenta sheets. Use --min-component-pixels 1 to retain every detached
pixel. All retained connected components survive, not just the largest body.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def separators(projection: np.ndarray, partitions: int = 4) -> list[int]:
    """Find adaptive gutters near expected partitions (4-way legacy equivalent)."""
    projection = np.asarray(projection)
    length = len(projection)
    if partitions < 1 or length < max(partitions, 5):
        raise ValueError("Partition count must be positive and fit the image axis (minimum 5 pixels).")
    if projection.ndim != 1 or np.any(projection < 0):
        raise ValueError("Projection must be one-dimensional and nonnegative.")
    cuts = [0]
    smooth = np.convolve(projection, np.ones(5), mode="same")
    # Forty percent of nominal cell width reproduces legacy +/-10% for 4.
    radius = length / partitions * .40
    for i in range(1, partitions):
        ideal = length * i / partitions
        lo = max(cuts[-1] + 1, round(ideal - radius))
        hi = min(length - (partitions - i) + 1, round(ideal + radius))
        if hi <= lo:
            raise ValueError("Image axis too small to locate distinct adaptive gutters.")
        minimum = smooth[lo:hi].min()
        valid = np.flatnonzero(smooth[lo:hi] <= minimum + 1) + lo
        runs = np.split(valid, np.where(np.diff(valid) > 1)[0] + 1)
        run = min(runs, key=lambda r: abs(float(np.mean(r)) - ideal) - min(len(r), 60) * .7)
        cuts.append(round(float(np.mean(run))))
    return cuts + [length]


def magenta_cleanup(image: Image.Image, key_difference: int = 25) -> Image.Image:
    """Binary alpha; preserve source RGB and pre-existing transparent regions."""
    if not 0 <= key_difference <= 255:
        raise ValueError("Key difference must be between 0 and 255.")
    rgba = np.array(image.convert("RGBA"))
    rgb = rgba[:, :, :3].astype(np.int16)
    key = ((rgb[:, :, 0] - rgb[:, :, 1] > key_difference)
           & (rgb[:, :, 2] - rgb[:, :, 1] > key_difference))
    opaque = (~key) & (rgba[:, :, 3] >= 128)
    rgba[:, :, 3] = np.where(opaque, 255, 0)
    rgba[~opaque] = 0
    return Image.fromarray(rgba)


def extract_cells(image: Image.Image, columns: int = 4, rows: int = 4,
                  min_component_pixels: int = 5, key_difference: int = 25
                  ) -> tuple[list[Image.Image], dict]:
    """Return cropped RGBA cells and JSON-compatible review metadata in memory.

    Rectangles use [left, top, right, bottom], right/bottom exclusive. Components
    use four-neighbor connectivity, matching the existing Cattle Trail extractor.
    Grid cuts are heuristic: metadata flags content crossing a cut for review.
    Empty cells raise ValueError before a caller writes any output.
    """
    if min_component_pixels < 1:
        raise ValueError("Minimum component size must be at least 1.")
    clean = magenta_cleanup(image, key_difference)
    opaque = np.array(clean.getchannel("A")) > 0
    ycuts = separators(opaque.sum(axis=1), rows)
    frames, records, warnings = [], [], []
    for cut in ycuts[1:-1]:
        if opaque[max(0, cut - 1):cut + 1].any():
            warnings.append(f"Horizontal cut at y={cut} touches foreground; inspect neighboring rows.")
    row_cuts = []
    for row in range(rows):
        band = opaque[ycuts[row]:ycuts[row + 1]]
        xcuts = separators(band.sum(axis=0), columns)
        row_cuts.append(xcuts)
        for cut in xcuts[1:-1]:
            if band[:, max(0, cut - 1):cut + 1].any():
                warnings.append(f"Row {row} cut at x={cut} touches foreground; inspect neighboring cells.")
        for column in range(columns):
            box = (xcuts[column], ycuts[row], xcuts[column + 1], ycuts[row + 1])
            rgba = np.array(clean.crop(box))
            labels, count = ndimage.label(rgba[:, :, 3] > 0)
            sizes = np.bincount(labels.ravel())
            sizes[0] = 0
            keep = sizes[labels] >= min_component_pixels
            removed_pixels = int(((rgba[:, :, 3] > 0) & ~keep).sum())
            rgba[:, :, 3] = np.where(keep, 255, 0)
            rgba[~keep] = 0
            cell = Image.fromarray(rgba)
            trim = cell.getbbox()
            if not trim:
                raise ValueError(f"Empty cell at row={row}, column={column}; check grid/key/filter settings.")
            frame = cell.crop(trim)
            index = len(frames)
            frames.append(frame)
            records.append({
                "index": index, "row": row, "column": column,
                "file": f"cell_{row:02d}_{column:02d}.png",
                "source_rect": list(box), "trim_rect_in_cell": list(trim),
                "source_trim_rect": [box[0] + trim[0], box[1] + trim[1],
                                     box[0] + trim[2], box[1] + trim[3]],
                "size": list(frame.size),
                "rgba_sha256": hashlib.sha256(frame.tobytes()).hexdigest(),
                "components_before_filter": count,
                "components_kept": int((sizes[1:] >= min_component_pixels).sum()),
                "removed_small_component_pixels": removed_pixels,
            })
    return frames, {
        "schema_version": 1, "status": "extracted_candidates_pending_visual_review",
        "source_size": list(image.size), "columns": columns, "rows": rows,
        "rect_convention": "left/top/right/bottom; right and bottom exclusive",
        "processing": {"magenta_difference": key_difference, "source_alpha_threshold": 128,
                       "min_component_pixels": min_component_pixels, "connectivity": 4,
                       "rescaled": False, "all_retained_components_preserved": True},
        "ycuts": ycuts, "xcuts_by_row": row_cuts,
        "review_warnings": warnings, "cells": records,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output_directory", type=Path)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--rows", type=int, default=4)
    parser.add_argument("--min-component-pixels", type=int, default=5)
    parser.add_argument("--key-difference", type=int, default=25)
    args = parser.parse_args(argv)
    source = args.source.resolve(strict=True)
    output = args.output_directory.resolve()
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        parser.error("Output directory must be absent or empty; existing review files will not be overwritten.")
    with Image.open(source) as image:
        cells, metadata = extract_cells(image, args.columns, args.rows,
                                        args.min_component_pixels, args.key_difference)
    metadata["source"] = str(source)
    metadata["source_sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
    metadata["extractor_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    output.mkdir(parents=True, exist_ok=True)
    for cell, record in zip(cells, metadata["cells"]):
        path = output / record["file"]
        cell.save(path)
        record["png_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(output), "cells": len(cells),
                      "review_warnings": metadata["review_warnings"], "status": metadata["status"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
