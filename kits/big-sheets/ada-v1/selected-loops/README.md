# Ada role-loop selections

Two complete eight-pose candidate loops selected chronologically from sheet 04. These files preserve the existing whole-character pixels and extraction anchors. They contain no copied padding, invented intermediate drawings or mirrored poses.

| Clip | Original sheet indices | Duration | Visible action |
| --- | --- | --- | --- |
| idle | 0–7 | 1.70 seconds | A small head look upward and back to neutral |
| talk | 16–23 | 1.96 seconds | Open palm, point, chuckle, open hands, settle |

`atlas.png` contains two rows of eight 256×256 cells. `actor-spec.json` specifies exact rectangles, frame durations, source indices, hashes and the common [128, 244] foot pivot at four source pixels per world unit. `idle-review.png` and `talk-review.png` are transparent animated PNGs. The seam images show the final two poses followed by the first pose, without introducing additional animation frames.

Both loops return to a compatible neutral pose, but neither is declared visually approved or admitted into the live room. The idle sequence is better described as looking around than breathing. The conversation sequence reads as a stepped gesture sequence; large arm movements still need authored intermediate poses for fluid animation. Face, braid, torso and boot contours drift between drawings, including at the loop seam. Preserving all eight unique frames is not evidence that these defects are solved.

The repair row was not selected because the raised wrench resembles a strike and the action does not maintain a convincing work contact. The camp row was not selected because the mug duplicates during a sipping pose and disappears through later gestures. Those are missing production loops, not completed content.

Rebuild with `python kits/big-sheets/ada-v1/selected-loops/build.py` from the project root. The builder verifies the source pixel hashes, eight distinct frames per clip and an exact decoded APNG pixel round trip. Those checks prove preservation, not motion quality. No game render was used.
