# Clip Maker — annotations to clips

Turn the selections in your Raven selection tables into named `.wav` clips, in the browser, with nothing uploaded anywhere.

**Open it:** https://blegottesman.github.io/PAM_Dashboards/annotations2clips/clip-maker.html

Or download `clip-maker.html` and double-click it. It is one file, works offline, and needs no install.

## What it does

1. Drop in one or more Raven selection tables (`.txt`, `.csv`, `.tsv`).
2. Point it at the folder of recordings (WAV or FLAC, subfolders included).
3. It tells you, in plain words, how it will find each sound:
   - tables with **Begin File + File Offset** are located directly;
   - tables with only **Begin Time / End Time** are located on Raven's stitched-together timeline (your recordings lined up in the order Raven opened them). If the table also has Begin File, that column is used to double-check the result.
4. Choose which rows to clip (by class, by confidence, or everything).
5. Choose the clip names. Default: `{Class}_{recording}_{start}s_{length}s`. Any column from the table can go into the name. Clips are sorted into one folder per class by default.
6. Look at a few spectrograms with the selection box drawn on them, click to listen, and confirm the times are right.
7. Make the clips. You also get `clips.csv` (every clip, its source recording, times and all the original columns) and `README.txt` (the settings used).

Advanced settings: context padding before/after, equal-length clips (long selections are split into `_p1`, `_p2` …), output sample rate, decimals and zero-padding in names.

Selections that run past the end of a recording are joined with the start of the next one. Recordings with the same file name in different subfolders are told apart with the table's Begin Path column.

The interface is available in **English** and **Bahasa Indonesia** (toggle at the top right).

## Browsers

| | Open a folder of recordings | Save clips straight into a folder |
|---|---|---|
| Chrome, Edge, Opera, Arc, Brave | yes | yes |
| Safari, Firefox | yes | no — clips arrive as one ZIP download |

Everything runs on your own computer. The page has no server and makes no network requests.

## Raven and time — the one thing worth knowing

A Raven selection table starts out with Begin Time, End Time, Low/High Frequency and your annotation columns. When you open several files in Raven, it stitches them into one long timeline, so Begin Time counts from the start of the *first* file that was open, not the file the sound is in. Raven can add **Begin File**, **Begin Path** and **File Offset** columns (selection table column settings); File Offset is the time inside the sound's own file, which is exactly what is needed to cut a clip. If your tables don't have those columns yet, turning them on in Raven will make clipping unambiguous for everyone downstream.

## About the code

One HTML file: HTML, CSS and plain JavaScript, no libraries. It parses WAV and FLAC headers itself and copies only the bytes each clip needs; FLAC decoding and resampling use the browser's Web Audio API; folder access uses the File System Access API with a ZIP fallback; spectrograms are a short-time Fourier transform drawn on a canvas. The source is readable in any text editor and is meant to be changed. All interface text lives in one translation table near the top of the script, so adding a language is a matter of filling in that table.

Designed, specified and customised by Benjamin Gottesman (K. Lisa Yang Center for Conservation Bioacoustics, Cornell Lab of Ornithology). Code written by Claude (Anthropic).

Licence: Apache-2.0, as for the rest of this repository.

## Version history

- **2.1** (Nov 2026) — English/Indonesian toggle; no external dependencies; remembers settings and last folders; folder drag-and-drop; README.txt alongside clips.csv; same-name recordings resolved by Begin Path; clips joined across file boundaries; runs inside Claude with ZIP delivery.
- **2.0** (Nov 2026) — Renamed from Selection Clipper; plain-language location step; several tables at once; spectrogram check gallery; clips.csv manifest; one folder per class by default; equal-length clips; sample-rate option.
- **1.0** — Selection Clipper: single table, Raven/BirdNET → WAV clips.
