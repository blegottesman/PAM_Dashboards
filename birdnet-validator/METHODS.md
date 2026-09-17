# Validating a BirdNET model: a two-page protocol

A short methods note you can hand to a trainee, adapt into a manuscript's methods
section, or follow yourself. It describes what to do and why; the tool in this
folder is one way to do it, not the only one.

---

## 1. What you are actually estimating

A classifier gives each three-second segment a score between 0 and 1. That score
is **not** a probability that the bird is there — it is a number whose relationship
to truth depends on your recorder, your site, your season and your species. The
purpose of validation is to learn that relationship for *your* data, so you can
choose a cut-off and say what it buys you.

The quantity the cut-off buys is **precision**: of the detections you keep, what
fraction are real. You estimate it by labelling a sample of detections and fitting
score → outcome.

Note what this does *not* give you: **recall**. Reviewing detections tells you
nothing about the calls the model never scored. If your question needs recall —
occupancy, density, anything where absence matters — you also need a set of
recordings annotated independently of the model, and that is a different and more
expensive exercise. Say clearly which one you did.

---

## 2. Choosing what to label

Three decisions, and each one has a way of going wrong.

**Which detections.** Sample across the whole score range, not just the top. A
sample of only high-confidence detections cannot estimate where precision falls
off, which is the thing you are trying to find. Set the minimum confidence low
(0.1–0.25) and use balanced sampling — equal numbers drawn from each of ten score
bins — so the low end is represented.

**How many.** Aim for on the order of **100 labelled clips per class**, spread
across the range, with both true and false positives present. Below about 50 the
fitted threshold moves a lot with a handful of labels; below about 20 it is not
worth reporting. If a class has no false positives in your sample, the fit cannot
be made and the honest answer is that you do not know the threshold yet.

**From where.** Spread the sample across sites, dates and times of day. A
threshold fitted on dawn recordings at one quiet site will not hold at a roadside
site at midday. If your deployment spans conditions, stratify by them and either
fit separately or check that the fits agree.

---

## 3. Labelling

Label **one class at a time**. Deciding "is this species A" is a different
perceptual task from "is this species B", and interleaving them makes you worse at
both.

For each clip, decide from the audio and the spectrogram together. Use three
labels:

- **true positive** — the target species is audible in the segment;
- **false positive** — it is not;
- **unsure** — you cannot tell.

Keep "unsure" as a real category and do not let it drift into "probably yes". What
you do with unsures is a reporting decision: excluding them is the common choice
and inflates precision slightly; counting them as false positives is the
conservative choice. State which you did.

Where false positives cluster on a *particular* other sound — another species, rain,
a vehicle, a chainsaw — record what it actually was rather than only that it was
wrong. That turns a validation set into a diagnosis, and it is often the most
useful thing to come out of the exercise. (In this tool, add relabel classes with
their own hotkeys.)

**Blind yourself where you can.** Reviewing in descending confidence order tells
you the model's answer before you give yours, and you will agree with it more than
you should. Review in random order.

Report who labelled, their experience with the species, and — if more than one
person labelled — the agreement between them on a shared subset.

---

## 4. Fitting the threshold

Fit a logistic regression of outcome (1 = true positive, 0 = false positive) on
confidence score, per class. BirdNET-Analyzer uses
`sklearn.linear_model.LogisticRegression(C=55)`, and this tool matches it so that
numbers are comparable with what the standard pipeline produces.

The threshold for a target precision *p* is

```
conf = ( log( p / (1 - p) ) - intercept ) / coefficient
```

Report the threshold **with the sample it came from**: n, the true/false split,
and the score range you sampled. A threshold without its n is not interpretable.

If the target precision falls outside the range the fit reaches within
[0, 1], say it is not achievable rather than extrapolating past the data. A
precision of 0.99 is frequently not achievable for a species the model confuses.

---

## 5. What to report

At minimum, in a methods section:

- classifier and version (e.g. BirdNET-Analyzer v2.x, model version, custom
  classifier if any) and the analysis settings (overlap, sensitivity, segment
  length, any location/date filtering);
- how detections were sampled for validation — score range, sampling scheme,
  stratification, and n per class;
- who labelled, in what order, and how "unsure" was handled;
- the fitting method (logistic regression, `C = 55`) and, per class, the fitted
  threshold at your chosen target precision with its n and true/false split;
- the tool and version used, so the analysis can be reproduced.

Deposit the labelled table itself. It is small, it is the actual evidence, and it
lets a reader check the fit rather than take it on faith. The CSV this tool
exports is a suitable supplementary file: one row per clip, with file, start and
end time, predicted class, confidence, label and the build that wrote it.

---

## 6. A worked sentence

> Detections were validated in BirdNET Validator v1.0.0. For each class we drew a
> balanced sample of detections across ten confidence bins between 0.1 and 1.0
> (n = 120 per class, stratified across four sites and three survey dates) and
> reviewed them in random order, blind to confidence score. Clips were labelled
> true positive, false positive or unsure by a single observer familiar with the
> local avifauna; unsure clips (4.2%) were excluded. Logistic regression of
> outcome on confidence (`C = 55`, matching BirdNET-Analyzer) gave a confidence
> threshold of 0.74 for a target precision of 0.90 in Hawaiʻi ʻAmakihi
> (n = 118; 61 true, 57 false). The labelled table is provided as Supplementary
> Data S1.
