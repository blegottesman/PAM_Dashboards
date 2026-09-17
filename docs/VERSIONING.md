# Versioning

## The scheme

Each tool has its own version, `MAJOR.MINOR.PATCH`:

| Bump | When | Example |
|---|---|---|
| **PATCH** `1.0.0 → 1.0.1` | A bug fix. Nothing you knew about the tool changes. | FLAC seeking fixed for files with no seektable |
| **MINOR** `1.0.0 → 1.1.0` | Something new you can use. Everything old still works, old project files still open. | Per-class spectrogram bands added |
| **MAJOR** `1.0.0 → 2.0.0` | Something changed that could break an old project file, or change a number someone already published. | Threshold fitting method changed |

The rule that matters: **if a result someone already reported would come out
different, that's a MAJOR bump, and the changelog says so in the first line.**
Everything else is a judgement call and getting it slightly wrong is fine.

Tags in this repo are namespaced by tool, because the tools version independently:

```
birdnet-validator-v1.0.0
clip-reviewer-v0.3.0
amakihi-meme-explorer-v1.2.0
```

A tool below `1.0.0` is saying "this still moves under you." That is a useful
thing to be able to say — don't rush to 1.0.

## Where the version lives

Three places, and they must agree:

1. **In the tool**, next to the title in the page header. Someone sends you a
   screenshot and you can tell which build they were running.
2. **In what the tool writes.** The validator stamps `appVersion` into every
   `.bnv.json` and a `validator_version` column into every CSV export. A result
   set can always be traced back to the build that produced it — which is the
   whole reason to bother with any of this.
3. **In the git tag and the release.**

When you change a tool, change the version constant in the file *in the same
commit* as the change. A build whose header lies about its version is worse than
one with no version at all.

In the validator the constant is near the top of the project-state section:

```js
var APP_VERSION="1.0.0";
```

There is a second, separate number there — `PROJ_VERSION` — which is the *file
format* version, not the tool version. It only changes when the shape of the
`.bnv.json` changes in a way that older builds could not read. It is expected to
sit at `1` for a long time.

## The changelog

Each tool folder has a `CHANGELOG.md`, newest at the top. Add to it as you make
the change, not when you make the release — by release time you will have
forgotten the half of it that mattered.

Write it for the person who has to decide whether to upgrade: what changed for
them, not what you did to the code. "Spectrogram FFT window is now chosen from the
visible band, so low-frequency species are legible" is useful. "Refactored
`autoNfft`" is not.
