# Release — v2.0-alpha.1, "The Design System"

Two prompts. Nothing is pushed to `main` until Saba says go in R2.

Decided 28 Oct: **web deploys are paused** at this release. Pushing to `main` normally makes
Vercel publish the web app, and the web hasn't had its redesign pass. The live web app stays
exactly as it is until then.

---

## R1 — get the release ready (no push to main)

````
1. **Back up the branch first:** push `feature/v2-design-system-revamp` to origin (it is ~131
   commits ahead of main, and origin's copy is behind). Report the pushed SHA.
2. **Pause web deploys from this commit on:** in vercel.json add
   `"git": { "deploymentEnabled": { "main": false } }`. If the Vercel CLI is logged in on this
   Mac, also confirm in the project settings that nothing else will deploy `main`, and report.
   Don't change any other Vercel setting.
3. **Version, in lockstep** (product/versioning_and_git_strategy.md §4):
   - pubspec `version: 2.0.0-alpha.1+2` (the build number goes up for the release binary)
   - `kCoveCurrentAppVersion = '2.0.0-alpha.1'`
   - the About screen
   - tool/check_version.dart must pass
4. **What's new:** rewrite the v2.0-alpha.1 `ChangelogItem` so `title`, `tagline` and `outcome`
   read as the user-facing copy below (Cove's voice: plain, no jargon). Keep `underTheHood` as
   the technical summary, updated to include Phases 3–4. Date: the release day.
5. tool/check.sh must exit 0 on the final commit. Report the commit SHA that will become
   `v2.0-alpha.1`.
6. Build the release APK from that commit, and report its versionName, versionCode and signing
   certificate SHA-256. It must match the certificate on both phones (the same check as 4.7f).
   Don't install it yet.

Commit as `release: v2.0-alpha.1 — The Design System`. Stop and report.
````

### What's new — copy for the changelog item

- **title:** `v2.0-alpha.1 — The Design System`
- **tagline:** `Cove, put together: one look, one way to add, and a home screen that knows your day.`
- **outcome:**

> Every screen has been redrawn to one design — calmer type, figures in Bodoni, and soft
> squircle corners throughout, in light and dark.
>
> Today reads like paper: the things on your day as tickets, receipts and notes, and a short
> letter that sums up the day.
>
> Adding anything is now one question at a time, with "Again" to repeat the last thing you
> logged.
>
> Four home-screen widgets — the day as a ring, a list you can tick, the month's spending,
> and the day as a printed page.
>
> Notifications now say what actually happened ("Ancy logged ₹820 for coffee beans") and
> group quick list changes into one.
>
> Say whose an event, task or routine is, and tag anything with Lyla, Cabo or Luca.
>
> Undo really undoes, invites never send your home's key anywhere, and nothing ever makes up a
> number.

## R2 — merge, tag, push (only after Saba says go)

````
1. Confirm main has no commits that the feature branch lacks (`git rev-list --count
   feature/v2-design-system-revamp..main` = 0). If it isn't 0, stop.
2. Before merging, tag the current main as the archive point:
   `git tag -a v1.0-alpha.2-final -m "main before the v2 merge"`.
3. `git checkout main && git merge --ff-only feature/v2-design-system-revamp`.
4. `git tag -a v2.0-alpha.1 -m "The Design System"` on that commit.
5. Push main and both tags: `git push origin main --follow-tags`. Confirm on Vercel (CLI or
   dashboard) that no deployment was triggered. If one was, cancel it at once and report.
6. Install the R1 release APK on both phones with `adb install -r` (never uninstall). The
   "What's new" sheet is keyed to the display version, which both phones have already seen, so
   it may not pop up again. If it doesn't, that's expected; it's in Settings → What's new.
   Report the logcat for each phone's first launch.
````
