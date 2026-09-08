"""Package existing whole sprites for the optional Lantern encounter; no admission.

Run from any directory: python tools/build_lantern_art.py
Copies existing RGBA cells without scaling, painting, or alpha changes. Validation
finishes for both actors before any generated output is written.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_cell(image, size, anchor, sockets):
    require(image.mode == "RGBA" and list(image.size) == size, "Unexpected RGBA cell dimensions")
    alpha = image.getchannel("A")
    require(set(alpha.tobytes()) == {0, 255}, "Cell must contain binary transparent and opaque pixels")
    bounds = alpha.getbbox()
    require(bounds and 0 < bounds[0] < bounds[2] < size[0] and 0 < bounds[1] < bounds[3] < size[1], "Empty or edge-clipped silhouette")
    require(0 <= anchor[0] < size[0] and 0 <= anchor[1] < size[1], "Anchor outside cell")
    require(bounds[3] <= anchor[1], "Silhouette extends below authored ground anchor")
    for name, point in sockets.items():
        require(len(point) == 2 and all(isinstance(v, int) for v in point), f"Invalid socket {name}")
        require(0 <= point[0] < size[0] and 0 <= point[1] < size[1], f"Socket outside cell: {name}")
    return list(bounds)


def package(actor, folder, selections):
    directory = ROOT / "kits/workcycles" / folder
    metadata_path = directory / "metadata.json"
    meta = json.loads(metadata_path.read_text(encoding="utf-8"))
    require(sha(ROOT / meta["source"]) == meta["source_sha256"], "Original source hash changed")
    size, anchor = meta["cell"], meta["anchor"]
    atlas = Image.new("RGBA", (size[0] * len(selections), size[1]))
    frames, clips, frame_sockets = [], {}, {}
    for index, (original_index, clip, filename) in enumerate(selections):
        original = meta["frames"][original_index]
        input_path = directory / filename
        image = Image.open(input_path)
        sockets = {name: value["cell_pixel_xy"] for name, value in original.get("sockets", {}).items()}
        bounds = validate_cell(image, size, original["anchor"], sockets)
        pixel_hash = hashlib.sha256(image.tobytes()).hexdigest()
        if "rgba_sha256" in original:
            require(pixel_hash == original["rgba_sha256"], "Source cell pixel hash changed")
        atlas.paste(image, (index * size[0], 0))
        frame = {
            "id": f"{actor}_{index:03d}", "atlas_rect": [index * size[0], 0, *size],
            "anchor": original["anchor"], "alpha_bounds_xyxy": bounds,
            "source": meta["source"], "source_sha256": meta["source_sha256"],
            "source_rect": original.get("source_crop_xyxy", original.get("source_cell_ltrb")),
            "trim": original.get("trim_xyxy_in_crop", original.get("trim_ltrb_in_cell")),
            "source_frame_index": original_index,
            "input_cell": input_path.relative_to(ROOT).as_posix(), "input_cell_sha256": sha(input_path),
            "rgba_sha256": pixel_hash, "source_record": original,
        }
        frames.append(frame)
        frame_sockets[str(index)] = sockets
        clips[clip] = {"frames": [index], "fps": 1, "loop": True, "presentation": "static state hold"}
    # Actor.configure starts idle. This is an explicit alias, not an extra drawing.
    clips["idle"] = dict(clips[selections[0][1]])
    spec = {"texture": f"res://assets/lantern/{actor}.png", "cell": size, "anchor": anchor,
            "frames": frames, "clips": clips, "count": len(frames), "frame_sockets": frame_sockets,
            "default_facing": "east" if actor == "eleanor_lantern" else "northeast",
            "status": "encounter_bundle_spirit_integrated_carry_poses_optional",
            "provenance": {"metadata": metadata_path.relative_to(ROOT).as_posix(),
                           "metadata_sha256": sha(metadata_path), "source_sha256": meta["source_sha256"],
                           "processing": "Exact existing whole RGBA cells repacked; no rescale or pixel edits"}}
    return spec, atlas


def main():
    bundles = {
        "eleanor_lantern": package("eleanor_lantern", "eleanor-lantern-v1", [
            (0, "carry_idle_east", "00-whole-frame.png"),
            (1, "carry_idle_northeast", "01-whole-frame.png"),
            (3, "carry_idle_south", "03-whole-frame.png")]),
        "crossing_spirit": package("crossing_spirit", "crossing-spirit-v1", [
            (i, state, state + ".png") for i, state in enumerate(["wary", "agitated", "listening", "settled"])])}
    manifest = {"schema_version": 1, "status": "encounter_bundle_spirit_integrated_carry_poses_optional",
                "encounter": "lanterns_at_the_ford", "sprites": {},
                "limitations": ["Static whole-pose states only; no carry walk or transition cycle.",
                                "Eleanor northwest omitted because source carry hand is inconsistent.",
                                "Lantern is baked into Eleanor; sockets locate its grip and light, not a second prop.",
                                "Crossing spirit sockets are empty: no authored attachment points.",
                                "The crossing spirit is connected to the source room controller; Eleanor carry poses remain optional and visual approval is outstanding."]}
    target = ROOT / "assets/lantern"
    target.mkdir(parents=True, exist_ok=True)
    for actor, (spec, atlas) in bundles.items():
        destination = target / (actor + ".png")
        atlas.save(destination)
        spec["texture_sha256"] = sha(destination)
        spec["atlas_size"] = list(atlas.size)
        manifest["sprites"][actor] = spec
    (ROOT / "assets/lantern-art.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("LANTERN ART PASS: 7 exact whole RGBA cells; binary alpha, bounds, anchors, sockets and source hashes validated; optional bundle only")


if __name__ == "__main__":
    main()
