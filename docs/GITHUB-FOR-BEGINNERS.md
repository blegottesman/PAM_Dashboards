# GitHub, for someone who has an account and not much else

This is written for you, Ben, for this repo specifically. No command line. Nothing
here needs git installed. If you follow it top to bottom once, you will have a
public home for these tools, a live web link for each one, and a way to make
changes without fear.

Read the first three sections now and the rest when you need them.

---

## The one idea that makes GitHub make sense

A **repository** ("repo") is a folder. That's it. GitHub stores the folder, and it
also stores every version of it you have ever saved, forever.

That second part is the whole point. You are not managing files; you are keeping a
history. That means you can change anything, because nothing is ever lost. The
cost is that you have to say, each time you save, *what* you changed — that
sentence is called a **commit message**, and six months from now it is the only
thing standing between you and archaeology.

Everything else — branches, pull requests, forks — is machinery for several people
editing at once. **You do not need any of it.** Working alone, you can edit files
directly on github.com and press a green button. Skip the rest until someone else
joins you.

---

## 1. Create the repo and put this folder in it

1. Go to <https://github.com/new>.
2. **Repository name:** `bioacoustics-dashboards`
3. **Description:** `Browser tools for passive acoustic monitoring: BirdNET validation, clip review, detection exploration`
4. Choose **Public**. (These have no secrets in them and public is what makes the
   web links work on a free account.)
5. Leave "Add a README file" **unchecked** — this folder already has one. Leave
   the licence and .gitignore dropdowns alone for the same reason.
6. Press **Create repository**.

You will land on an empty repo page with some instructions. Ignore them and look
for the link that says **uploading an existing file**.

7. Click it, then drag the **contents** of the `bioacoustics-dashboards` folder
   into the browser window — the folders (`birdnet-validator`, `docs`, …) and the
   loose files (`README.md`, `LICENSE`, …), not the enclosing folder itself.
   Dragging folders works and keeps their structure.
8. In the box at the bottom, where it says "Commit changes", write
   `Initial upload: four dashboards, docs and examples`.
9. Press **Commit changes**.

That's it. That is the whole act of "putting things on GitHub." Everything from
here is optional polish.

> **Note on size.** `amakihi-meme-explorer/index.html` is about 30 MB because the
> data is baked into the file. GitHub will take it, but see "Files that are too
> big" at the end before you upload a *second* 30 MB version of it.

---

## 2. Turn on the web links

Right now the files are stored. This makes them *open in a browser*, which is what
lets you send someone a link instead of an attachment.

1. In your repo, click **Settings** (the tab across the top, far right).
2. In the left sidebar, click **Pages**.
3. Under "Build and deployment" → **Source**, choose **Deploy from a branch**.
4. **Branch:** `main`, folder: `/ (root)`. Press **Save**.
5. Wait a minute or two, then reload the page. It will show a link like
   `https://blegottesman.github.io/bioacoustics-dashboards/`.

Now `https://blegottesman.github.io/bioacoustics-dashboards/birdnet-validator/`
opens the validator, live, for anyone you send it to. The Launch links in the
README start working at this point.

This is *better* than sending the file, because the folder-access API the
validator uses works on `https://` pages and the tool loads in under a second.

---

## 3. Changing something

This is the loop you will repeat forever.

**To edit a text file** (a README, say): open it on github.com, click the pencil
icon, edit, then at the bottom write what you changed and press **Commit changes**.

**To replace a file** (a new build of a dashboard): go to the folder, press
**Add file → Upload files**, drag the new version in with the *same filename*,
write a commit message, commit. GitHub keeps the old one in the history.

**Commit messages.** One line, present tense, says what changed and ideally why:

- good: `Fix FLAC seeking on files with no seektable`
- good: `Add per-class spectrogram frequency band`
- useless: `update`, `changes`, `v2`, `asdf`

You will break this rule when you are tired. Try not to break it when you have
just fixed something subtle — that is exactly the commit you will be hunting for.

**If you break something:** click the commit count near the top of the file list,
find the last version that worked, open the file at that version, and copy its
contents back. Nothing is ever actually lost. This is the safety net that makes it
reasonable to change things boldly.

---

## 4. Releases: the part that matters for a paper

A **release** is a snapshot with a name, frozen and downloadable. It is how you
answer "which version did you use?" in a methods section, and it is the thing you
cite.

1. On your repo's main page, in the right sidebar, click **Releases** → **Create a
   new release**.
2. **Choose a tag** → type a new one: `birdnet-validator-v1.0.0` → "Create new tag
   on publish".
3. **Release title:** `BirdNET Validator 1.0.0`
4. **Description:** paste the top section of that tool's `CHANGELOG.md`.
5. Under **Attach binaries**, upload the single `index.html` renamed to
   `birdnet-validator-1.0.0.html`. This is the thing people download, and its
   name tells them what they have.
6. **Publish release**.

Make a release when something changes that would alter someone's results, when you
are about to cite it, or before a workshop. Not for a typo fix.

See [VERSIONING.md](VERSIONING.md) for what the numbers mean.

---

## 5. A DOI, so it can be cited properly

A GitHub link is not a citable object — repos can move or vanish. Zenodo mints a
permanent DOI for each release and archives a copy.

1. Sign in to <https://zenodo.org> with your GitHub account.
2. Go to your Zenodo account → **GitHub** in the left sidebar.
3. Find `bioacoustics-dashboards` in the list and flip the switch **on**.
4. Now make a release (section 4). Only releases created *after* you flip the
   switch get archived — if you already made one, make the next one.
5. Zenodo emails you a DOI within a few minutes. It appears back on the Zenodo
   GitHub page as a badge you can paste into your README.

Then the methods sentence becomes: *"Detections were validated using BirdNET
Validator v1.0.0 (Gottesman 2026, doi:10.5281/zenodo.XXXXXXX)."* That is a
reference a reader can actually follow, which a link to a live file is not.

Update [CITATION.cff](../CITATION.cff) with the DOI when you have it — GitHub reads
that file and shows a "Cite this repository" button on your repo page.

---

## 6. Things that will confuse you, answered

**"main" vs "master."** Same thing; `main` is the current default name. Don't
worry about it.

**Branches.** A parallel copy of the folder so two people can work without
colliding. Working alone, stay on `main`.

**Pull requests.** A request to merge a branch into `main`, with review. You don't
need them. If a colleague ever sends you one, it is a proposed change and there's
a green button to accept it.

**Issues.** A to-do list attached to the repo, one item per thread. Genuinely
useful even alone: when a trainee says "the spectrograms look wrong for owls",
open an issue. It is a better place for that than your inbox.

**Forks.** Someone's own copy of your repo. When a collaborator forks and changes
something, their changes are theirs until they send you a pull request.

**Stars.** Bookmarks. Not a metric to care about.

**Files that are too big.** GitHub warns above 50 MB and refuses above 100 MB, and
the history keeps *every* version — so a 30 MB file replaced ten times is 300 MB
of repo forever. For the meme explorer specifically, if you find yourself
re-uploading it often, the fix is to split the embedded data out into a `.json`
file the page fetches at load. The page stops being one file, but a code change
then costs kilobytes instead of tens of megabytes. Not urgent; worth doing before
the fifth re-upload.

**Making a repo private later.** Settings → bottom of the page → Change
visibility. But GitHub Pages needs a paid plan for private repos, so the live
links would stop working.

---

## 7. If you ever do want the command line

You don't need it for this. But when editing on the website gets tedious — and it
does, once you are changing several files at once — the smallest useful thing is
**GitHub Desktop** (<https://desktop.github.com>), which is the same loop with a
folder on your Mac: edit files normally, open the app, see what changed, write a
message, press **Commit**, press **Push**. No terminal.

That is the natural next step, and it is the only one. You can run this repo for
years without ever typing `git` into a terminal.
