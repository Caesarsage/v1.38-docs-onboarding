# Running release notes — step by step

The recipe. For *why* it works this way, and the failure modes, read
[release-notes.md](release-notes.md) after.

Worked example uses **v1.37**, which is already cut, so nothing you do here can affect v1.38.

## The whole thing in four sentences

1. Every PR merged into `k/k` can carry a release note in its description.
2. `krel` collects every note between the last tag and this one, and **asks you about each one**.
3. Your answer is saved as a small YAML file — one per PR — under `maps/`.
4. The published notes are those YAML files rendered into Markdown. **The maps are the source of
   truth; the draft is output.**

That last point is the one that catches people. Editing `release-notes-draft.md` by hand feels like
it works, and the next `krel` run silently destroys it.

---

## Part 1 · Set up, once

### Install `krel`

```shell
go install k8s.io/release/cmd/krel@latest
```

Or from a [`kubernetes/release`](../../../release) checkout: `./hack/get-krel`, or
`./compile-release-tools krel`.

Check it: `krel version`.

### Token

Make a GitHub token with **`public_repo` scope only** — nothing else.

```shell
export GITHUB_TOKEN=ghp_yourtokenhere
```

### Editor

`krel` reads `$KUBE_EDITOR` first, then `$EDITOR`. Setting `KUBE_EDITOR` leaves your git editor
alone:

```shell
export KUBE_EDITOR="code -w"     # or "subl -w", or vim / nano
```

**VS Code and Sublime need the `-w`.** Without it the command returns the instant it hands the file
over, so `krel` sees an unsaved file and records the note unchanged — silently. Test it first; this
should block until you close the tab:

```shell
code -w /tmp/krel-test.yaml
```

If `code` isn't found: VS Code → `Cmd+Shift+P` → *Shell Command: Install 'code' command in PATH*.
Hand control back by closing the **tab**, not the window. Don't put quotes or backslashes inside the
variable — krel splits it on spaces, and anything fancier gets punted to `$SHELL`.

**Turn off format-on-save for YAML.** If Prettier or another formatter runs on save, `Cmd+S`
re-indents the map and can break it. Either save with `Cmd+K S` (*Save without Formatting*), or
rely on `"files.autoSave": "afterDelay"`, which saves without running formatters. With auto-save
on, closing the tab no longer discards your edits: to skip a note, undo back to the original or
empty the file.

---

## Part 2 · The run

### Step 1 — know your tag

You cut notes **after** a pre-release tag is pushed. v1.37's were:

`v1.37.0-alpha.1` · `alpha.2` · `alpha.3` · `beta.0` · `rc.0` · `rc.1` · final

Our v1.38 dates are in [Sheet 2 of the responsibility sheet](../CHECKLIST.md), first one
**Wed 23 Sep**.

### Step 2 — run it

```shell
krel release-notes \
  --create-draft-pr \
  --fork=<your-github-username> \
  --tag "v1.37.0-alpha.2" \
  --fix \
  --log-level trace 2>&1 | tee krel-output.log
```

| Flag | What it does |
|---|---|
| `--tag` | Which pre-release you're cutting notes for |
| `--fork` | **Your** GitHub username — where the branch gets pushed |
| `--fix` | Turns on the interactive review. Without it you get a draft nobody has read. |
| `--create-draft-pr` | Opens the PR against `k/sig-release` at the end |
| `--nomock` | **Add this for a real cut.** Without it the run is a mock and your edits don't reach a PR. |
| `tee` | Keep the log. When something goes wrong this is the only record. |

**Run it from any directory.** `krel` clones `k/k` to `$TMPDIR/k8s` (cached, so only the first run
downloads it) and `k/sig-release` to its own temp dir, which it deletes after opening the PR.
Neither is your working checkout, and nothing you have open is touched.

It then queries every PR in range. **This is slow** — minutes early in the cycle, much longer near
Code Freeze. Expected, not broken.

You also need an **SSH key on your GitHub account**: krel pushes the branch over SSH, not with
`GITHUB_TOKEN`. The token only covers the API call that opens the PR. Check with
`ssh -T git@github.com`.

### Step 3 — say yes to the first prompt

Before anything happens you get:

```
Create draft pull request? (Y/n)
```

**Answer `Y`, or press Enter.** This is not just the PR — the clone, the gather, the `--fix` review
loop and the map writing are all inside the function this prompt guards. Answer `n` and krel does
nothing at all, then prints `Release notes generation complete!` anyway. That message is
unconditional; it does not mean work happened.

You get a **second** prompt at the very end, after the review loop, and *that* is the one that
actually files the PR:

```
Create pull request with your changes? (y/n)
```

Because you passed `--fix`, krel always asks this rather than filing automatically. Answer `n` and
it leaves the local `k/sig-release` clone in place with instructions for pushing by hand.

> ⚠️ **Practising against an old tag?** Say `n` to the second prompt. `--create-draft-pr` opens a
> real PR against `kubernetes/sig-release`, and `--nomock` does not prevent it. To explore with no
> PR path at all, drop `--create-draft-pr` — see [Part 4](#part-4--do-it-now-safely).

### Step 4 — the loop

First question:

```
Would you like to continue from the last session? (Y/n)
```

**Answer `Y` in a real run.** The session files then skip every note already reviewed, leaving only
what arrived since the last tag — that's what makes the rotation survivable. Answer `n` and you
review all ~350 from scratch, which is only useful when you're deliberately practising.

Then, per note:

```
Release Note for PR 138001:
===========================
Pull Request URL: https://github.com/kubernetes/kubernetes/pull/138001
✨ Note contents was previously modified with a map
    Author: @rogowski-piotr
    SIGs: [node testing]
    Kinds: [cleanup]
    Areas: [test]
    Feature: false
    ActionRequired: false
    DoNotPublish: false
 >> Text:
    │ Removed the `KubeletMinVersion` label from the DRA e2e test covering multiple
    │ ResourceClaims.

- Fix note for PR #138001? (y/N)
```

Two answers:

- **`n` / Enter** — the note is fine. Marked reviewed, never shown again.
- **`y`** — opens your editor.

Read the three signals before answering:

| Signal | Means |
|---|---|
| `✨ Note contents was previously modified with a map` | Someone already curated this. Usually `n`. |
| `>>` beside a field | *That* field is what the map changed. Fields without it are as the author wrote them. |
| No `✨` at all | Raw from the PR body, nobody has looked at it. This is where your work is. |

The example above is worth studying, because it's already correct. The author wrote *"Remove**s** the
`KubeletMinVersion` label ... multiple `` `ResourceClaims` ``"*; the map changed it to *"Remove**d**
... multiple ResourceClaims"* — past tense, and API kind unbackticked. Both style rules, in one
edit. Correct answer: `n`.

#### The giant red warning is noise

Every mapped note also prints:

```
level=warning msg="Original PR body of release note mapping changed for PR: #138001"
level=warning msg="The diff between actual release note body and mapped one is: ..."
```

…followed by the entire PR template in red. It fires because maps are written with `pr_body: ""`, so
the stored body never matches the real one. **It says nothing about the note.** Ignore it. Running
at `--log-level info` instead of `trace` cuts most of the surrounding noise.

**`Ctrl+C` is safe.** Progress is saved to a session file, so the next run resumes and only shows
you what's new. You are not expected to do 300 notes in one sitting.

### Step 5 — editing a note

The editor opens a YAML file where **changed fields are live and unchanged fields are commented
out**. To change something, uncomment the line and edit it:

```yaml
pr: 117119
releasenote:
  text: |-
    ACTION REQUIRED: Fixed `eventRecordQPS` handling in `kubelet` configuration to treat 0 as
    unlimited (no rate limit), aligning behavior with the documentation.
  # author: HirazawaUi
  sigs:
  - api-machinery
  - auth
  - node
  # kinds:
  # - bug
```

#### Saving and handing control back

krel logs the file it opened, then blocks:

```
level=info msg="Opening file with editor [code -w /var/folders/.../release-notes-map-2182480457.yaml]"
```

| Editor | Save, then |
|---|---|
| VS Code | `Cmd+K S` (or wait for auto-save), then **`Cmd+W` to close the tab** |
| Sublime | `Cmd+S`, then close the tab |
| vim | `:wq` |
| nano | `Ctrl+O`, Enter, `Ctrl+X` |

**In VS Code, saving is not enough** — `code -w` returns when the *tab* closes, not when the file is
written. Save and leave the tab open and krel sits there forever looking idle.

Changed your mind mid-edit? Close the tab without saving. krel logs *"YAML mapfile is blank,
ignoring"* and moves to the next note. Nothing is lost.

Other rules that actually bite:

- **`pr:` and `releasenote:` must stay uncommented.** Comment either out and the file is invalid.
- **Always include the note `text`, even when you only meant to change `sigs` or `kinds`.**
  `krel release-notes validate` fails a map with no `text` field.
- **Quote the text if it contains a colon followed by a space.** YAML reads `: ` as a new key, even
  inside backticks. `ACTION REQUIRED: …`, `labelSelector: {}` and `Accept: application/json` all
  need `text: "…"`. A colon followed by anything else, as in `https://` or `{"a":1}`, is fine.
- **Keep the text on one line**, or use `text: |-` with the continuation lines indented. Notes are
  one line per bullet, so don't hand-wrap them.
- **Indent consistently.** The simplest edit is to delete `# ` from `pr:` and `releasenote:`, so they
  start at the left edge, and `#` plus one space from `text:`, which leaves it indented two spaces.
- **Hide a note with `do_not_publish: true`** under `releasenote:`, for duplicates or for a change
  that a later PR in the same cycle cancels. It still needs `text`.
- Bad YAML → krel says so and offers a retry; you don't lose the note.
- What you write is what ships. Past tense, verb first, jargon explained.

Use the team's [release notes style cheatsheet](https://github.com/kernel-kun/release-team-utils/blob/main/release-notes-style-guide.md).
It adapts the [docs style guide](https://kubernetes.io/docs/contribute/style/style-guide/) for notes.
The rules that come up most:

| | |
|---|---|
| API kinds | plain PascalCase, no backticks: ConfigMap, ResourceClaim |
| Fields | backticked, as the API path: `` `status.reservedFor` ``, not the Go struct path |
| Components, flags, metrics, feature gates, versions | backticked: `` `kubelet` ``, `` `--fork` ``, `` `v1.38` `` |
| Graduation | Start case: Alpha, Beta, GA, never `BETA` |
| Field values | plain, unquoted: set `podManagementPolicy` to Parallel |
| Openings | no `kubelet:` or `DRA:` prefixes, and no "now", "e.g." or "we" |
| Periods | **outside** closing quotes |

If a note is vague, open the PR and write what changed for users. Where you can't tell, ask the
author rather than guessing.

### Step 6 — what you actually produced

One file per PR, in `releases/release-1.38/release-notes/maps/pr-<number>-map.yaml`.

Real one from 1.37 — [`pr-117119-map.yaml`](../../../sig-release/releases/release-1.37/release-notes/maps/pr-117119-map.yaml):

```yaml
pr: 117119
pr_body: ""
releasenote:
  text: |-
    ACTION REQUIRED: Fixed `eventRecordQPS` handling in `kubelet` configuration to treat 0 as
    unlimited (no rate limit), aligning behavior with the documentation. Users relying on the
    previous default behavior should explicitly set a non-zero value (for example, 50).
  sigs:
  - api-machinery
  - auth
  - node
  kinds:
  - bug
  areas:
  - kubelet
  - code-generation
```

That renders into the draft as the ACTION REQUIRED bullet you can read at
[`release-notes-draft.md`](../../../sig-release/releases/release-1.37/release-notes/release-notes-draft.md).
1.37 accumulated **350** of these.

**Your maps won't look like that yet.** krel saves only the lines you uncommented, usually just
`pr`, `releasenote` and `text`. It also copies the whole PR description into `pr_body`. Step 8
brings them into the team layout above.

### Step 7 — the PR

On exit `krel` offers to push and open the PR for you. Say yes — it pushes to your `sig-release`
fork and files it.

Decline and it leaves the clone in a temp dir; you push by hand. Either way **check that both
`release-notes-draft.md` and `release-notes-draft.json` are in the diff.** They must move together.

### Step 8 — clean up the maps

Check out the PR branch in your `sig-release` fork and run
[`normalize_maps.py`](normalize_maps.py). It keeps your `text` and any field you set, fills in
`sigs`, `kinds` and `areas` from `release-notes-draft.json`, and sets `pr_body: ""`:

```shell
git fetch origin release-notes-draft-<tag>
git switch -c release-notes-draft-<tag> --track origin/release-notes-draft-<tag>

python3 normalize_maps.py releases/release-1.38/release-notes
krel release-notes validate --path-to-release-notes releases/release-1.38/release-notes/maps
```

Maps that are already in the layout don't change, so it's safe to run at every cut. To hide a map
from an earlier cut, add its PR number after the path; the script sets `do_not_publish: true` on it.

`validate` makes zero API calls and takes well under a second over hundreds of files. Commit and push
to the same branch.

### Step 9 — the PR description

Use the team template. Take the numbers from the branch, not from krel's output:

- **Total flagged**: entries in `release-notes-draft.json`, the whole minor cycle so far
- **Modified via map files**: files in `maps/`
- **Untouched**: the difference

List every note you hid with `do_not_publish: true` and why, and every note you think needs
`ACTION REQUIRED` but didn't mark. Those are SIG decisions, so raise them rather than make them.

---

## Part 3 · Reviewing someone else's

Every run has an assignee *and* a reviewer. As reviewer, check:

- [ ] Every PR merged since the last tag was processed — cross-check against `k/k`, `krel` can skip
      some ([k/release#4381](https://github.com/kubernetes/release/issues/4381))
- [ ] Notes read as past-tense, verb-first English with jargon explained
- [ ] `ACTION REQUIRED` notes are in **Urgent Upgrade Notes**, not buried in Changes by Kind
- [ ] SIG labels on each note look right, and none is empty
- [ ] Same-version dependency updates and changes that cancel each other in the cycle are merged or
      hidden, not published twice
- [ ] Every map follows the team layout: `pr_body: ""`, `sigs`, `kinds`
- [ ] `.md`, `.json` and the map files agree

Don't block on style nits. Correctness and completeness first.

---

## Part 4 · Do it now, safely

A real run against 1.37 that touches nothing:

```shell
# 1. Generate from raw PR data — no maps, no PR, nothing written upstream
krel release-notes --tag v1.37.0-alpha.2

# 2. Same tag, with the team's 350 maps applied — diff the two.
#    Everything that differs is human editing work.
krel release-notes --tag v1.37.0-alpha.2 \
  --maps-from /absolute/path/to/sig-release/releases/release-1.37/release-notes/maps
```

`--maps-from` needs an **absolute** path — krel runs from its own temp clone, so a relative path
resolves somewhere you didn't mean.

Then open one map beside its rendered bullet in the draft and read them together. That single
comparison teaches the model faster than any explanation.

---

## Sources

- [kernel-kun's v1.37 shadow runbook, §8](https://github.com/kernel-kun/release-team-utils/blob/main/v1.37-docs-shadow-runbook.md#8-krel-core-release-notes)
- [editing-flow.md](../../../sig-release/release-team/role-handbooks/docs/editing-flow.md)
- [krel installation](https://github.com/kubernetes/release/tree/master/docs/krel#installation)
- [release-notes.md](release-notes.md) — the deep version, with labs
