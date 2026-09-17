# Bioacoustics Dashboards

Small, self-contained browser tools for passive acoustic monitoring (PAM) work —
validating classifier output, exploring detections, labelling clips. Each one is a
single HTML file that runs offline in a browser. **No install, no server, no upload:
your audio is read from disk by the browser and never leaves your machine.**

Maintained by Ben Gottesman. Built for Hawaiian honeycreeper work and used in
BEAT / TEMABio training, but nothing in them is specific to those projects.

---

## What's here

| Tool | What it does | Open it |
|---|---|---|
| [**BirdNET Validator**](birdnet-validator/) | Review BirdNET detections class by class, label true/false positives with hotkeys, and fit the confidence threshold that buys you a target precision. Replaces the Segments → Review folder shuffle. | [Launch](https://blegottesman.github.io/bioacoustics-dashboards/birdnet-validator/) |
| [**Clip Reviewer**](clip-reviewer/) | Lightweight one-at-a-time clip labeller for a folder of pre-cut segments. | [Launch](https://blegottesman.github.io/bioacoustics-dashboards/clip-reviewer/) |
| [**Amakihi Meme Explorer**](amakihi-meme-explorer/) | Explore song-type ("meme") structure and sharing across Hawaiʻi ʻAmakihi recordings. Data is embedded in the file. | [Launch](https://blegottesman.github.io/bioacoustics-dashboards/amakihi-meme-explorer/) |
| [**Suaq Swamp Dashboard**](suaq-swamp/) | *Not yet added — see the folder's README for how to drop it in.* | — |
| [**Duke Farms Detection Explorer**](duke-farms-explorer/) | R/Shiny app for exploring BirdNET detections spatially and temporally. Needs R, so it runs locally rather than in the browser. | [How to run](duke-farms-explorer/README.md) |

The "Launch" links start working once you enable GitHub Pages — see
[docs/GITHUB-FOR-BEGINNERS.md](docs/GITHUB-FOR-BEGINNERS.md).

---

## Two ways to use any of these

**From the web** (easiest to share): click the Launch link. The page loads from
GitHub Pages; your data still stays local.

**From a file** (works with no internet): on a tool's folder page click the HTML
file, then the **Download raw file** button, and open the downloaded file in your
browser. Email it, put it on a USB stick, hand it to a trainee — it is one file and
it has no dependencies.

### Browser support

The validator opens **folders** of audio, which needs the File System Access API.
As of 2026 that ships in **Chrome, Edge, Opera and Arc** but not Safari or Firefox.
The tools still work in Safari and Firefox — audio comes in through a file picker
instead, and saving a project downloads a copy rather than writing back to the same
file — but for hour-long archives Chrome or Edge is markedly less painful. Each tool
says so on screen when it detects a browser without the API.

One quirk worth knowing: the folder API is only available on `https://` and
`file://` pages, so the GitHub Pages copy and a downloaded copy both work, but a
copy served over plain `http://` will not.

---

## Citing and versioning

Each release is tagged (`birdnet-validator-v1.0.0`, and so on) and every tool
stamps its own version into the files it writes, so a result set can always be
traced back to the build that produced it. See
[docs/VERSIONING.md](docs/VERSIONING.md) for the scheme and
[CITATION.cff](CITATION.cff) for how to cite the repo.

## Licence

MIT — see [LICENSE](LICENSE). Use it, change it, teach with it. If it saves you
time in a paper, a citation is appreciated but not required.
