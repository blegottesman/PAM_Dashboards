# Amakihi Meme Explorer

Explores song-type ("meme") structure and sharing among Hawaiʻi ʻAmakihi
recordings — which song types occur where, how they cluster, and how they overlap
between individuals and sites.

**[Launch it](https://blegottesman.github.io/bioacoustics-dashboards/amakihi-meme-explorer/)**
· or download `index.html` and open it locally.

## A note on the file

The dataset is embedded directly in the HTML, which is why the file is around
30 MB. That is a deliberate trade: the page needs nothing else, works offline, and
can be emailed as one file.

The cost shows up in the repo. Git keeps every version forever, so each re-upload
adds another ~30 MB to the history permanently. If this file starts changing
often, split the embedded data into a `data.json` the page fetches at load — the
page stops being self-contained, but a code change then costs kilobytes instead of
tens of megabytes. Until then, this is fine.
