# Open-source training research: folding laundry with OpenArm v1

Research snapshot: 2026-09-01

## Executive summary

There is now a directly relevant open-source path. Hugging Face's **Unfolding Robotics** project trained bimanual OpenArm systems to fold T-shirts and released its LeRobot pipeline, data, hardware modifications, and evaluation recipe. The published project reports its best policy reaching **90% success across 20 physical rollouts** (100% on laid-out-shirt folding and 80% on the harder spread/fold/place task), but that result used a large multi-rig effort and substantial compute. It is evidence that the approach can work, not a plug-and-play guarantee for a stock OpenArm v1.

For this project, the practical first milestone is smaller: reproduce dataset loading and a training/evaluation loop using the 50-episode OpenArm dataset, then collect 30-50 consistent demonstrations per shirt/background on the actual v1 hardware. Do not start by attempting to reproduce the published 131-hour, 8-rig run.

## Most relevant open-source assets

| Resource | What is available | Fit for this project | Caveat |
| --- | --- | --- | --- |
| [LeRobot OpenArm integration](https://github.com/huggingface/lerobot/blob/main/docs/source/openarm.mdx) | CAN setup, calibration, single-arm and bimanual teleoperation, recording, and OpenArm follower/leader classes | Primary hardware and learning stack | Track a known LeRobot release; `main` changes quickly |
| [Unfolding Robotics recipe](https://huggingface.co/spaces/lerobot/robot-folding) | Hardware, collection, training, evaluation, ablations, and lessons from a physical bimanual OpenArm deployment | Closest end-to-end reference | The exact OpenArm hardware revision is not explicitly identified in the recipe; v1 compatibility must be verified |
| [`lerobot/high_quality_folding`](https://huggingface.co/datasets/lerobot/high_quality_folding) | 1,200 episodes, about 3.2M frames / 30 hours, LeRobot v3.0, 30 FPS, 16D bimanual actions, base + two wrist cameras | Best public fine-tuning/reference dataset | Camera geometry, arm extension, grippers, calibration, and setup differ from a stock v1 |
| [`TobiBrtnr/openarm_shirt_folding_new_converted`](https://huggingface.co/datasets/TobiBrtnr/openarm_shirt_folding_new_converted) | 50 episodes, 135,766 frames, LeRobot v2.1, 30 FPS, three 480x640 cameras, Apache-2.0 | Smallest direct OpenArm pipeline smoke test | Old schema exposes 48D state and 32D action; it needs careful remapping before deployment to the current 16D bimanual interface |
| [OpenArm dataset toolkit](https://github.com/enactic/openarm_dataset) | Inspect, validate, merge, convert, and upload OpenArm datasets; supports LeRobot v2.1/v3.0 and GR00T | Useful for making locally collected data reproducible | Conversion does not solve semantic mismatches in joint order, units, or camera names |
| [OpenArm hardware repository](https://github.com/enactic/openarm) | Open hardware, assembly, control, simulation, and linked subprojects | Ground truth for the v1 platform | Pin the exact v1 assets/configuration rather than assuming current defaults describe v1 |
| [OpenArm MuJoCo v1 model](https://github.com/enactic/openarm_mujoco/blob/master/v1/openarm_bimanual.xml) | Bimanual v1 model and assets | Collision/workspace checks and controller prototyping | Cloth simulation is not yet a substitute for real folding demonstrations |
| [OpenArm Isaac Lab](https://github.com/enactic/openarm_isaac_lab) | OpenArm RL environments for reach, lift, drawer, and bimanual reach | Useful for controls and sim-to-real groundwork | Garment imitation-learning environments were described as under development, so this is not the shortest path to folding |
| [Laundrynauts / LeHome Challenge](https://github.com/cwoodhayes/lehome-laundrynauts) | Isaac Lab garment simulation plus LeRobot configs for ACT, Diffusion Policy, and SmolVLA | Good secondary benchmark and policy-config reference | Targets a simulated SO-101 setup, not physical OpenArm v1 |
| [Stanford Behavior Prompting laundry task](https://github.com/real-stanford/behavior_prompting/blob/main/docs/laundry_folding.md) | Bimanual sweater-folding data, checkpoints, and recovery demonstrations | Useful ideas for failure recovery and correction data | Authors warn the checkpoints are not in-the-wild and likely will not transfer directly |

## What the closest OpenArm result actually used

The Unfolding Robotics setup used:

- Bimanual 7-DoF OpenArm followers with one gripper per arm (16 action dimensions total).
- One base RGB camera and two wrist RGB cameras; no depth, tactile, force, audio, or IMU input.
- Custom wider gripper surfaces and a 5 cm upper-arm extension.
- Lightweight OpenArm Mini leader arms, wrist straps, and a foot pedal for episode control.
- Real-world leader-follower demonstrations rather than cloth RL from scratch in simulation.
- A consistent fold strategy, deliberately varied shirts/backgrounds/viewpoints, and recorded evaluation video.

The full collection contained 5,688 episodes (~131 hours). A curated 1,200-episode subset (~30 hours) had a much larger effect than the tested algorithmic changes. Their published recommendation is to begin with **30-50 clean demonstrations per item/background**, train a baseline, inspect its failures, and only then expand the dataset.

## Training findings worth carrying over

1. **Start with behavior cloning / imitation learning.** Cloth contact and deformation make real-world demonstrations the shortest credible route for this hardware.
2. **Prioritize a single, repeatable folding strategy.** Mixing multiple valid strategies at small data scale diluted the signal; mirroring augmentation performed poorly in the published ablation.
3. **Data curation matters more than raw volume.** Fine-tuning on the curated dataset improved the reported best run from 40% to 90% overall success.
4. **Use a pretrained policy when compute permits.** The strongest public recipe fine-tuned Pi 0.5 with relative actions and reward-aligned behavior cloning. It used 8 H100 GPUs for its large experiments, so this is not the first local smoke test.
5. **ACT or SmolVLA are sensible initial baselines.** They have LeRobot training support and are cheaper to iterate than the published Pi 0.5 setup. Compare them only after the dataset/action pipeline is proven.
6. **Relative actions helped Pi 0.5.** LeRobot's recipe computes chunk targets relative to the current state while retaining absolute state observations. Treat this as model-specific until verified for the chosen baseline.
7. **Use human-in-the-loop correction after a baseline works.** DAgger-style corrections target actual failure states more efficiently than indiscriminate extra demonstrations.
8. **Smooth inference matters.** The reference used Real-Time Chunking and action interpolation to avoid stop-and-go motion. These are deployment improvements, not substitutes for a correct policy.

## OpenArm v1 compatibility checks

Before commanding hardware, resolve and record all of the following:

- Exact OpenArm release/tag and the v1 URDF/MJCF revision used by the physical robot.
- Left/right CAN interface assignments and unique motor IDs.
- Joint order, sign, zero offset, units, limits, and gripper range expected by LeRobot.
- Whether the v1 driver reports the same 16-position state/action contract as `bi_openarm_follower`.
- Camera keys, orientation, resolution, frame rate, and latency.
- Workspace and self-collision limits for the table height and arm spacing.
- Emergency-stop procedure, conservative speed/torque limits, and a dry-run mode.
- Dataset-to-robot mapping. In particular, do not send the older 32D dataset action vector directly to a 16D robot interface.

## Proposed staged plan

### Stage 0: freeze the environment

- Record the OpenArm v1 hardware revision and photograph/measure the setup.
- Pin Ubuntu, Python, LeRobot, OpenArm firmware/driver, CUDA, and camera versions.
- Calibrate each arm separately, test CAN, then test bimanual teleoperation at conservative limits.
- Define one T-shirt, one table/background, one camera layout, and one deterministic fold sequence.

Exit criterion: repeatable bimanual teleoperation, synchronized camera capture, and a verified emergency stop.

### Stage 1: offline data smoke test

- Download only metadata and a few episodes from the 50-episode OpenArm dataset.
- Inspect videos, joint ordering, ranges, timing, missing frames, and task labels.
- Convert or rename fields into the pinned LeRobot schema without losing provenance.
- Train a small ACT baseline far enough to prove dataloading, checkpointing, and offline inference.

Exit criterion: a reproducible command produces a checkpoint and replays predictions with correct shapes/ranges. No physical deployment yet.

### Stage 2: local demonstration pilot

- Practice the fold before recording.
- Record 30-50 successful, smooth demonstrations for the fixed shirt/background.
- Reject episodes with poor grasps, pauses, collisions, occluded cameras, or inconsistent fold sequences.
- Hold out shirts/episodes before training; never evaluate only on training garments.

Exit criterion: dataset validation passes, episode videos are reviewable, and action/state distributions match the robot interface.

### Stage 3: physical baseline

- Train ACT first; optionally compare SmolVLA after ACT establishes the pipeline.
- Deploy with strict joint/action clamping, low speed, operator E-stop, and rollout recording.
- Evaluate on 5 held-out shirts, 2 trials each (10 rollouts), reporting binary success, stage completion, fold quality, and time.

Exit criterion: the policy completes at least one full fold safely and failures are categorized from video.

### Stage 4: targeted improvement

- Collect corrective demonstrations at the observed failure states.
- Add garment/background/viewpoint diversity gradually.
- Compare absolute versus relative actions for the selected policy.
- Only after a stable baseline, evaluate SARM/RABC, RTC, action interpolation, or a larger pretrained VLA.

## Immediate next artifacts to add

- `hardware.md`: exact v1 revision, CAN map, camera inventory, geometry, and safety limits.
- `environment.lock`: pinned LeRobot/OpenArm/CUDA/Python versions.
- Dataset inspection script that validates feature names, shapes, units, rates, and episode duration.
- A task protocol with photos of each fold stage and explicit success/failure criteria.
- An evaluation manifest listing held-out garments and rollout results.

## Sources

- [LeRobot: OpenArm hardware guide](https://github.com/huggingface/lerobot/blob/main/docs/source/openarm.mdx)
- [LeRobot: imitation learning on real robots](https://huggingface.co/docs/lerobot/main/en/il_robots)
- [Unfolding Robotics: open-source folding recipe](https://huggingface.co/spaces/lerobot/robot-folding)
- [High-quality OpenArm folding dataset](https://huggingface.co/datasets/lerobot/high_quality_folding)
- [50-episode OpenArm shirt-folding dataset](https://huggingface.co/datasets/TobiBrtnr/openarm_shirt_folding_new_converted)
- [OpenArm dataset format and conversion tools](https://github.com/enactic/openarm_dataset)
- [OpenArm project](https://github.com/enactic/openarm)
- [OpenArm Isaac Lab](https://github.com/enactic/openarm_isaac_lab)
- [LeHome Laundrynauts](https://github.com/cwoodhayes/lehome-laundrynauts)
- [Behavior Prompting laundry-folding task](https://github.com/real-stanford/behavior_prompting/blob/main/docs/laundry_folding.md)

