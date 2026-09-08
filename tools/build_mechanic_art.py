"""Package existing whole sprites for the mechanic controller without resampling."""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "mechanic"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rgba_hash(image: Image.Image) -> str:
    return hashlib.sha256(image.tobytes()).hexdigest()


def checked_cell(image: Image.Image, cell: list[int], anchor: list[int]) -> None:
    assert image.mode == "RGBA" and list(image.size) == cell, "Incorrect RGBA cell size"
    assert len(anchor) == 2 and 0 <= anchor[0] < cell[0] and 0 <= anchor[1] < cell[1], "Anchor outside cell"
    pixels = np.array(image)
    assert set(np.unique(pixels[:, :, 3])).issubset({0, 255}), "Nonbinary alpha"
    assert not pixels[pixels[:, :, 3] == 0].any(), "Nonzero hidden RGB"
    bounds = image.getbbox()
    assert bounds is not None, "Empty whole sprite"
    assert 0 < bounds[0] < bounds[2] < cell[0] and 0 < bounds[1] < bounds[3] < cell[1], "Sprite reaches cell edge"


def package(
    kit: str, filenames: list[str], clip_names: list[str], output_name: str, default_facing: str,
) -> tuple[dict, Image.Image]:
    folder = ROOT / "kits" / "workcycles" / kit
    metadata_path = folder / "metadata.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    source = ROOT / metadata["source"]
    assert sha256(source) == metadata["source_sha256"], "Generated source changed: " + str(source)
    cell = metadata["cell"]
    anchor = metadata["anchor"]
    candidate = Image.open(folder / metadata["texture"]).convert("RGBA")
    atlas = Image.new("RGBA", (cell[0] * len(filenames), cell[1]), (0, 0, 0, 0))
    frames = []
    for index, filename in enumerate(filenames):
        previous = metadata["frames"][index]
        original_rect = previous.get("atlas_rect_xywh", previous.get("atlas_rect"))
        assert original_rect is not None and len(original_rect) == 4
        x, y, w, h = original_rect
        assert 0 <= x and 0 <= y and x+w <= candidate.width and y+h <= candidate.height, "Candidate region outside atlas"
        image_path = folder / filename
        image = Image.open(image_path).convert("RGBA")
        frame_anchor = previous.get("anchor", anchor)
        checked_cell(image, cell, frame_anchor)
        assert image.tobytes() == candidate.crop((x, y, x+w, y+h)).tobytes(), "Individual sprite differs from candidate atlas"
        assert rgba_hash(image) == previous["rgba_sha256"], "Candidate frame pixels changed"
        atlas.paste(image, (index * cell[0], 0))
        frame = deepcopy(previous)
        frame.update({
            "id": f"{kit}_{index:03}",
            "index": index,
            "atlas_rect": [index * cell[0], 0, cell[0], cell[1]],
            "anchor": list(frame_anchor),
            "source": metadata["source"],
            "source_sha256": metadata["source_sha256"],
            "candidate_atlas_rect": list(original_rect),
            "candidate_image": image_path.relative_to(ROOT).as_posix(),
            "candidate_image_sha256": sha256(image_path),
            "source_frame_metadata": deepcopy(previous),
            "alpha_bounds_xyxy": list(image.getbbox()),
        })
        # Keep one unambiguous runtime region; original conventions remain in provenance.
        frame.pop("atlas_rect_xywh", None)
        frames.append(frame)
    clips = {name: {"frames": [i], "fps": 1, "loop": True} for i, name in enumerate(clip_names)}
    clips["idle"] = {"frames": [0], "fps": 1, "loop": True}
    spec = {
        "texture": "res://assets/mechanic/" + output_name,
        "cell": cell,
        "anchor": anchor,
        "default_facing": default_facing,
        "frames": frames,
        "clips": clips,
        "status": "packaged_whole_static_source_frames",
        "source_metadata": metadata_path.relative_to(ROOT).as_posix(),
        "source_metadata_sha256": sha256(metadata_path),
        "source_processing": deepcopy(metadata.get("processing", {})),
        "source_inspection": deepcopy(metadata.get("inspection", {})),
        "packaging": {"rescaled": False, "recolored": False, "redrawn": False, "pixel_equality_verified": True},
    }
    if "scale" in metadata:
        spec["source_extraction_scale"] = metadata["scale"]
    return spec, atlas


def main() -> None:
    # Ada remains stationary in the mechanic encounter. Select the detailed
    # elevated master without inventing directional walking from static poses.
    source = ROOT / "kits/wardrobe/ada-high-angle-v1/atlas.png"
    master = json.loads((source.parent / "actor-spec.json").read_text(encoding="utf-8"))
    ada_atlas = Image.open(source).convert("RGBA")
    assert ada_atlas.size == (256,256) and ada_atlas.getbbox()
    assert set(ada_atlas.getchannel("A").get_flattened_data()) <= {0,255}
    ada = {key:master[key] for key in ["cell","anchor","pixels_per_world_unit","directional","default_facing","frames","frame_anchors","clips"]}
    ada.update(age=22, character_id="ada_mercer", texture="res://assets/mechanic/ada-mercer.png",
        source_texture=source.relative_to(ROOT).as_posix(), source_sha256=sha256(source),
        status="detailed_stationary_encounter_review", runtime_admitted=True,
        review="Whole elevated adult master inspected for complete silhouette, opaque period-inspired clothing and hard binary alpha. Stationary encounter selection only; no walk or turn approval.")
    machine, machine_atlas = package(
        "steam-cattle-handler-v1", ["idle.png", "stalled.png", "repaired.png"],
        ["idle_southwest", "stalled", "repaired"], "steam-handler.png", "southwest",
    )
    assert all(frame["actual_direction"] == "southwest" for frame in machine["frames"])
    document = {
        "schema_version": 1,
        "status": "mechanic_controller_static_art_package",
        "sprites": {"ada_mercer": ada, "steam_handler": machine},
        "scope": "Existing whole static source pixels only. No walking-cycle admission or source-art edits.",
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, image in [("ada-mercer.png", ada_atlas), ("steam-handler.png", machine_atlas)]:
        destination = OUTPUT / name
        image.save(destination)
        assert Image.open(destination).convert("RGBA").tobytes() == image.tobytes(), "Saved atlas pixels changed"
    for spec in document["sprites"].values():
        spec["texture_sha256"] = sha256(ROOT / spec["texture"].removeprefix("res://"))
    destination = ROOT / "assets" / "mechanic-art.json"
    destination.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print("MECHANIC ART PASS: detailed stationary Ada; steam handler 3 southwest states; exact pixels, hashes, alpha, bounds and anchors verified")


if __name__ == "__main__":
    main()
