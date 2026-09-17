# Changelog — BirdNET Validator

Versions follow [semantic versioning](https://semver.org): `MAJOR.MINOR.PATCH`.
In practice, for a tool like this:

- **PATCH** (1.0.0 → 1.0.1) — a bug fix. Nothing you knew changes.
- **MINOR** (1.0.0 → 1.1.0) — something new you can use. Old project files still open.
- **MAJOR** (1.0.0 → 2.0.0) — something changed that could break an old project
  file or change a published number. Say what, loudly, here.

The build is shown in the page header and written into every `.bnv.json`
(`appVersion`) and every CSV export (`validator_version` column).

---

## 1.0.0 — 2026-09-16

First release.

**Workflow**

- Setup → Process → Review, using BirdNET's own segment-selection parameters
  (min/max confidence, random / confidence-ranked / balanced sampling with 10
  bins, segments per file, segment length).
- Loads a BirdNET combined table or per-file tables, with column mapping guessed
  and shown for correction. Also imports an existing Segments folder, reading
  `Positive/` and `Negative/` subfolders as labels.
- Review is scoped to one class at a time, with panels to page between classes and
  a sort by detection count.
- Gallery and single-clip views; hotkey labelling (`T`/`F`/`?`), click-to-select,
  shift-drag marquee, bulk relabel, and undo.
- User-defined relabel classes with their own hotkeys, per species.
- Save and reopen a whole annotation project as a `.bnv.json`; browser autosave as
  a crash net.
- CSV export with per-clip labels and relabels.

**Audio**

- Clips are cut on demand by byte-range seek into the original recording: WAV via
  header + PCM offset, FLAC by splicing a synthetic mini-FLAC around the frames
  that matter and handing it to the browser's own decoder. Roughly 7 ms per clip
  on a 345 MB WAV, against 5.8 s and 635 MB for a whole-file decode.
- FLAC frame boundaries are found by binary search over CRC-8-validated frame
  headers rather than estimated from average bitrate, which drifts badly on
  variable material.
- Filename matching is case- and extension-insensitive, so a CSV that says `.wav`
  still finds `.WAV` or `.flac` on disk.
- Multiple audio folders accumulate; files are opened on demand, never loaded up
  front.
- When a clip cannot be read, the card says why ("starts 2140 s into a 1800 s
  file", "no audio frame there", "could not decode this clip") instead of failing
  silently.

**Spectrograms**

- Per-class settings: frequency band, FFT window, dynamic range, brightness,
  background flattening, colormap (magma / viridis / ice / grey).
- FFT window is chosen automatically from the visible band (~70 bins across it),
  so a 0–1000 Hz view gets the resolution it needs rather than 11 bins.
- Normalisation is scoped to the displayed band at the 99th percentile, so
  narrow-band views don't wash out.
- Max-pooling on both axes when downsampling to the card, so brief signals survive
  the resize.
- Changing the band repaints a 93-card gallery in ~43 ms without re-reading audio.

**Thresholds**

- Logistic fit of confidence → outcome using BirdNET's own settings
  (`C = 55`), solved for target precisions 0.85 / 0.90 / 0.95 / 0.99, per class or
  pooled. Agrees with `sklearn` on the same labels to within 0.01.
- Targets that the fit cannot reach inside the confidence range are reported as
  "not reachable" rather than extrapolated.

**Honesty**

- Illustrative placeholder spectrograms are drawn **only** for the built-in sample
  dataset. With real detections loaded, a clip with no audio connected says so
  rather than showing art you might label.
