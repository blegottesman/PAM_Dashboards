# Clip Reviewer

A lightweight labeller for a folder of **pre-cut** audio clips: one clip at a
time, spectrogram and playback, keyboard labelling, CSV out.

**[Launch it](https://blegottesman.github.io/bioacoustics-dashboards/clip-reviewer/)**
· or download `index.html` and open it locally.

## When to use this instead of the BirdNET Validator

Use **Clip Reviewer** when you already have a folder of individual clip files and
just want them labelled — segments someone else cut, clips from another pipeline,
a hand-assembled set for a listening test.

Use the [**BirdNET Validator**](../birdnet-validator/) when you have a BirdNET
results table and the original long recordings, and you want the detections cut on
demand, reviewed class by class, and turned into a confidence threshold.

## Quickstart

1. Open the page.
2. Pick the folder of clips.
3. Label with the keyboard; the CSV export holds one row per clip.
