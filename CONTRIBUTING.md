# Contributing / Maintainer Guide

This document is for people **working on** the NewgroundsIO-AS3 library.
If you just want to *use* the library in a game, you want the [README](README.md) instead.

---

## Contents

- [What lives where](#what-lives-where)
- [Prerequisites](#prerequisites)
- [The release pipeline](#the-release-pipeline)
- [Step 1 — Regenerate the model classes](#step-1--regenerate-the-model-classes)
- [Step 2 — Rebuild the compiled class library](#step-2--rebuild-the-compiled-class-library)
- [Step 3 — Re-import the component into components_cs5.fla](#step-3--re-import-the-component-into-components_cs5fla)
- [Step 4 — Re-export the SWC](#step-4--re-export-the-swc)
- [Step 5 — Commit, tag, release](#step-5--commit-tag-release)
- [Verification checklist](#verification-checklist)

---

## What lives where

| Path | What it is | Edited by |
|---|---|---|
| `build/` | Generated model classes + hand-written core classes | `npm run build` (models), by hand (core) |
| `src/modelgen/` | Generator config + helpers | by hand |
| `src/templates/` | EJS templates the generator renders | by hand |
| `src/library/NgioClassLib.fla` | Wrapper FLA that produces the drag-and-drop component | Flash |
| `bin/components_cs5.fla` | **Release artifact.** All user-facing components | Flash |
| `bin/NgioClassLib.swc` | **Release artifact.** SWC for the advanced install path | Flash |
| `docs/` | Images used by the README | — |

`build/` mixes generated and hand-written code:

```
build/NGIO.as                  hand-written
build/io/newgrounds/*.as       hand-written (Core, AppState, Errors, SessionStatus, Base*, NGJSON, NgioEvent)
build/io/newgrounds/helpers/   hand-written
build/com/hurlant/             third-party crypto - do not edit
build/io/newgrounds/models/    GENERATED - do not hand-edit, it gets overwritten
```

---

## Prerequisites

### ⚠️ Flash version: committed `.fla` files must be in **Flash CS5** format

What matters is the format of the file you commit, not which IDE you type in.

**Use Flash CS5, or any later version still capable of saving to CS5 format.** CS5.5 and CS6 can
both do this — CS5.5 is what these files are currently maintained in. If you're on a version above
CS5, the workflow is:

1. Open and edit normally
2. Before committing, **File ▸ Save As** and choose **Flash CS5 Document** as the file type
3. Commit that CS5-format file

> **Never commit a `.fla` saved in a newer format.**
>
> Save As reaches back only a limited number of versions, so each release that passes puts CS5
> further out of reach — recent Animate versions can't get there at all. And the intermediate
> releases you'd need to walk a file back down are increasingly hard to obtain, with several no
> longer running reliably on current Windows.
>
> Before assuming your version works, check that **Flash CS5 Document** actually appears in its
> Save As type list. If it doesn't, use an older IDE — don't save the file.
>
> This applies to both `src/library/NgioClassLib.fla` and `bin/components_cs5.fla`.

| Requirement | Version |
|---|---|
| Committed `.fla` format | **Flash CS5** |
| Authoring IDE | **CS5**, or any later version that can save to CS5 (CS5.5, CS6) |
| Model generator | **Node.js 20+** |

> Sister project note: the AS2 library targets **Flash 8** instead. Keep the two toolchains straight
> if you work on both.

---

## The release pipeline

```
  1. npm run build          regenerates build/io/newgrounds/models/
             |
  2. NgioClassLib.fla       recompile the class library into NgioClassLibCompiled   [MANUAL, Flash]
             |
  3. components_cs5.fla     re-import the updated NgioLibraryComponent              [MANUAL, Flash]
             |
  4. NgioClassLib.fla       re-export bin/NgioClassLib.swc                          [MANUAL, Flash]
             |
  5. commit + tag v*        GitHub Action attaches bin/components_cs5.fla
                            and bin/NgioClassLib.swc to the release
```

> ### ⚠️ The CI build cannot rebuild either binary artifact
>
> The release workflow runs `npm run build`, which regenerates `build/`. It **cannot** touch the
> compiled clip inside `components_cs5.fla`, and it **cannot** regenerate the SWC — both require
> Flash.
>
> So if you change the core library and tag a release **without doing steps 2–4 by hand**, the
> published `components_cs5.fla` and `NgioClassLib.swc` ship a *stale* class library, even though
> the repo's `build/` folder looks correct. Users installing via the Connector, Library component,
> or SWC get the old code; only users copying source files get the new code.
>
> **Any change under `build/` means you must redo steps 2, 3 and 4 before tagging.**

---

## Step 1 — Regenerate the model classes

Only needed if the Newgrounds.io API schema changed, or you edited anything in `src/templates/`
or `src/modelgen/`.

```bash
npm install      # first time only
npm run build
```

This downloads the latest `objects_and_components.json` and rewrites
`build/io/newgrounds/models/`. Review the diff before continuing — a schema change can add or
remove whole component classes.

If you only hand-edited core classes (`Core.as`, `AppState.as`, a helper, etc.), skip to Step 2.

---

## Step 2 — Rebuild the compiled class library

**File:** `src/library/NgioClassLib.fla`
**Why:** this FLA's classpath points at `../../build`, so opening and recompiling it is what pulls
your updated classes into a distributable form.

### How it's put together

The stage contains one clip, **`NgioLibraryComponent`**, which hides itself on frame 1. It has two
layers:

| Layer | Contents | Purpose |
|---|---|---|
| `banner` (top) | A graphical banner | What the developer sees when they drag the component onto their stage |
| `class library` (bottom) | The `NgioClassLibCompiled` clip | Every class in `build/`, pre-compiled |

Pre-compiling is what lets novice users skip importing classes entirely, and saves advanced users
from long republish times.

### The procedure

1. Open `src/library/NgioClassLib.fla` in Flash.

2. **Clear out the old compiled clip.** Two places — both are required:

   a. On the stage, enter the `NgioLibraryComponent` clip, select the **`class library`** layer,
      and delete the `NgioClassLibCompiled` instance sitting on it.

   b. In the Library panel, go to `Newgrounds.IO ▸ assets ▸ library` and delete the
      **`NgioClassLibCompiled`** symbol.

   > Leaving either one behind means you'll recompile but keep shipping the old code.

3. **Recompile.** Still in the Library panel at `Newgrounds.IO ▸ assets ▸ library`, right-click
   **`NgioClassLib`** (the *uncompiled* symbol — note the name has no `Compiled` suffix) and choose
   **Convert to Compiled Clip**.

   This is the step that actually reads `../../build` and bakes the classes in.

4. **Rename** the newly created compiled symbol to exactly **`NgioClassLibCompiled`**.

   The name matters — Step 3 and the components FLA depend on it.

5. **Place it.** Drag a copy of `NgioClassLibCompiled` from the Library onto the
   **`class library`** layer inside the `NgioLibraryComponent` clip — the same layer you emptied
   in 2a.

6. **Save** `NgioClassLib.fla` and stage it for commit.

   > On a later IDE than CS5? Use **File ▸ Save As ▸ Flash CS5 Document** — the committed file must
   > be CS5 format.

---

## Step 3 — Re-import the component into components_cs5.fla

The updated `NgioLibraryComponent` now has to be carried across into the release artifact.

1. Open `bin/components_cs5.fla` in Flash.

2. **Clear out the old symbols.** Two places in the Library panel — both are required:

   a. Go to `Newgrounds.IO ▸ library` and delete **`NgioLibraryComponent`**.

   b. Go to `Newgrounds.IO ▸ assets ▸ library` and delete **`NgioClassLibCompiled`**.

   > ⚠️ **Two different `library` folders — don't mix them up.**
   > The component lives under `Newgrounds.IO ▸ library`.
   > The compiled clip lives under `Newgrounds.IO ▸ assets ▸ library`.

3. Switch back to `NgioClassLib.fla`, select **`NgioLibraryComponent`** on the root stage, and
   copy it.

4. Switch to `components_cs5.fla` and paste **anywhere** — the stage, any frame. Pasting is what
   imports the symbol (and its nested compiled clip) into the library.

   **If Flash asks whether to replace or duplicate existing library items, choose "Replace".**
   Duplicating leaves the stale symbols behind under `Copy of …` names and the component will keep
   using the old code.

   > **Where the symbol lands is version-specific — leave it wherever it goes.**
   > CS5 preserves the source library path on paste, so `NgioLibraryComponent` reappears under
   > `Newgrounds.IO ▸ library`, matching where it lives in `NgioClassLib.fla`. That's the natural
   > paste behaviour and it's fine — advanced users can navigate a folder. **Don't reorganise it.**
   >
   > The AS2 project ends up different for the same reason: Flash 8 *drops* the library path on
   > paste, so the symbol lands at the library root. Also left as-is — the AS2 audience skews
   > toward newer developers, so having it front and centre is the better default there.

5. Now **delete the pasted instance from the stage.** The symbol stays in the library, which is
   all we need; `components_cs5.fla`'s stage should end up unchanged.

6. **Save** `components_cs5.fla` and stage it for commit.

   > On a later IDE than CS5? Use **File ▸ Save As ▸ Flash CS5 Document** — the committed file must
   > be CS5 format.

---

## Step 4 — Re-export the SWC

`bin/NgioClassLib.swc` is a separate release artifact backing README *Installation Method 3 (Use
the Library SWC)*. It is built from the same source as the compiled clip, but it is **not** produced
by Steps 2 or 3 — it has to be exported on its own, or the SWC ships stale.

1. In `src/library/NgioClassLib.fla`, open the Library panel and go to
   `Newgrounds.IO ▸ assets ▸ library`.

2. Right-click **`NgioClassLib`** — the same *uncompiled* symbol you used in Step 2 — and choose
   **Export SWC File…**

3. Save over the existing **`bin/NgioClassLib.swc`**, replacing it.

4. Stage `bin/NgioClassLib.swc` for commit.

> Both Step 2 and this step read from `NgioClassLib`. Do them in the same sitting, from the same
> state of `build/`, so the compiled clip and the SWC can't disagree about what version of the
> library they contain.

---

## Step 5 — Commit, tag, release

```bash
git add src/library/NgioClassLib.fla bin/components_cs5.fla bin/NgioClassLib.swc
git add build/                              # if Step 1 regenerated anything
git commit -m "Rebuild compiled class library"
git push

git tag v1.0.1                              # your new version
git push origin v1.0.1
```

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which installs dependencies, runs
`npm run build`, and attaches **`bin/components_cs5.fla`** and **`bin/NgioClassLib.swc`** to the
GitHub release.

---

## Verification checklist

Before tagging:

- [ ] `build/io/newgrounds/models/` reflects the current schema (if Step 1 was run)
- [ ] `Newgrounds.IO ▸ assets ▸ library` in `NgioClassLib.fla` contains exactly one
      `NgioClassLibCompiled`, and it was created *after* your latest `build/` change
- [ ] The `class library` layer inside `NgioLibraryComponent` has the compiled clip on it
- [ ] `components_cs5.fla`'s `Newgrounds.IO ▸ library` has exactly one `NgioLibraryComponent`
- [ ] `components_cs5.fla`'s `Newgrounds.IO ▸ assets ▸ library` has exactly one
      `NgioClassLibCompiled`
- [ ] No `Copy of …` symbols anywhere in `components_cs5.fla`'s library (means "Duplicate" was
      picked instead of "Replace")
- [ ] `components_cs5.fla`'s **stage is empty** — no leftover pasted instance
- [ ] `bin/NgioClassLib.swc` re-exported from the same `build/` state as the compiled clip
- [ ] Both FLAs saved in **Flash CS5** format — if you authored in a later IDE (CS5.5, CS6), you
      did the **Save As ▸ Flash CS5 Document** step before staging
- [ ] All files saved and staged

A quick smoke test: publish `components_cs5.fla`, drag the Library component into a scratch FLA,
and confirm a class you just changed behaves as expected.

---

## Related

- Model generator: [ngio-object-model-generator](https://github.com/PsychoGoldfishNG/ngio-object-model-generator)
- Cross-platform design spec: [ngio-developer-guide](https://github.com/PsychoGoldfishNG/ngio-developer-guide)
