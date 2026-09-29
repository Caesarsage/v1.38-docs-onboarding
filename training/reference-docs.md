# Reference documentation generation — teaching this to shadows

Six reference sets, three generators, nine pull requests, and a window that opens the same day as
Docs Freeze. I've run this alone for the last two cycles; this cycle it gets split across the three
buddy pairs.

**The authoritative process is my own page**, [Generating Reference Documentation for a
Release](https://github.com/kubernetes/website/pull/57160) — `kubernetes/website#57160`, still open,
502 lines, part of umbrella [#56385](https://github.com/kubernetes/website/issues/56385). Every
command lives there. **This file does not repeat it.** What it adds is the four things the page
deliberately doesn't carry: *when* in the cycle, *who* does which set, what to rehearse, and the
gotchas that only show up on a real machine.

> **Before the pairs start:** #57160 needs to be merged, or shadows are working from an unmerged
> diff. If it hasn't landed by **Fri 30 Oct**, either chase a review or send them the PR's Netlify
> preview link. Don't have five people reading a raw diff.

---

## 1. Why this is hard

Everything else in the cycle is a deadline you can chase people about. This is a **build** that
depends on artifacts that don't exist until very late:

| Dependency | Available from | Blocks |
|---|---|---|
| A `kubernetes/kubernetes` release tag | `v1.38.0-beta.0` — **Wed 4 Nov** | everything |
| Published `k8s.io/*` staging modules at `v0.38.x` | **hours after** each tag | `gen-compdocs`, `genref` |
| A stable API surface | Code Freeze — **Mon 16 Nov** | output being final |

And the output is nine pull requests, three of them in a different repo, all of which must merge
before the website freezes on **Tue 15 Dec**.

The staging-module lag is the one that surprises people. `go get k8s.io/kubernetes@v1.38.0-rc.0`
succeeds while `k8s.io/api@v0.38.0` still 404s from `sum.golang.org`. Check before you debug:

```shell
git ls-remote --tags https://github.com/kubernetes/api.git "v0.${K8S_RELEASE#*.}"
```

Empty result means wait, not broken. The two API reference sets read only `swagger.json`, so **Pair A
can work through the lag** while the other two wait.

---

## 2. When — the cycle schedule

Two passes. This is the part that makes it teachable.

### Rehearsal — week 10, at `beta.0` (Wed 4 Nov)

Throwaway output, nothing merged. The point is to hit every failure mode a month early, while there's
still slack.

- [ ] Everyone gets their local setup working (§4) — this alone eats an afternoon the first time
- [ ] `make createversiondirs` for `v1_38`
- [ ] Swagger prep runs, and `verify-enum-swagger.sh` passes
- [ ] Each pair builds their set once and previews it
- [ ] **Check `genref/config.yaml` for new configuration API versions** — see §5, this is the one
      thing that isn't auto-detected and the most likely late surprise
- [ ] Note how long each build actually takes, so December isn't a guess

Discard the output. Record what broke in [log.md](../log.md).

### Real run — week 14, from `rc.0` (Thu 3 Dec)

`rc.0` is cut the same day as Docs Freeze. The API surface has been frozen since 16 Nov, so `rc.0`
output is effectively final — cherry-picks between `rc.0` and `rc.1` rarely touch the reference.
Generating at `rc.0` rather than `rc.1` buys twelve days of review instead of six.

| Date | Step |
|---|---|
| **Thu 3 Dec** | `rc.0` cut. Swagger prep. Pair A starts immediately (no staging dependency). |
| **Thu 3 Dec** | Staging modules should be up. Pairs B and C start. |
| **Fri 4 – Mon 7 Dec** | All nine PRs open. reference-docs PRs first; website PRs held behind them. |
| **Wed 9 Dec** | `rc.1`. Spot-check for surface changes; regenerate only if something moved. |
| **Fri 11 Dec** | Target: all three reference-docs PRs merged, website PRs unheld. |
| **Mon 14 Dec** | Target: all six website PRs merged into `dev-1.38`. |
| **Tue 15 Dec** | Website freezes. Anything unmerged now ships next cycle. |

**All six website PRs target `dev-1.38`**, so they flow to `main` in the release-day integration
merge. A reference PR against `main` is a mistake — it publishes v1.38 docs before v1.38 exists.

---

## 3. Who — the six sets across three pairs

The split falls out of the generators, and maps onto the pairs we already have.

| Pair | Generator | Sets | Website PRs | reference-docs PR |
|---|---|---|---|---|
| **A** | `gen-apidocs` | Kubernetes API (HTML) · Kubernetes API (Markdown) | 2 | 1 — `gen-apidocs/config/v1_38/` (config + swagger) |
| **B** | `gen-compdocs` | Components · kubectl · kubeadm | 3 | 1 — `gen-compdocs/go.mod` + `go.sum` |
| **C** *(me + shadow 5)* | `genref` | Configuration APIs | 1 | 1 — `genref/go.mod`, `config.yaml`, `output/md/` |

**Why this allocation:**

- **Pair A goes first and is unblocked** — only needs `swagger.json`, so they work through the
  staging-module lag. Two PRs from one generator run.
- **Pair B has the most PRs but the least judgement.** Critical efficiency note: each `copycomp-*`
  target *rebuilds every component page*, several minutes each time. Run `make copycomp` **once**,
  then split the result across three branches. Three separate `copycomp-*` runs is three rebuilds
  for the same bytes.
- **Pair C is mine because `genref` needs the judgement call** (§5). It's one PR and the least
  mechanical work, but the only step where a wrong answer silently omits a whole page.

I own the swagger prep before Pair A starts, and all nine PR descriptions get reviewed by me before
they go up.

---

## 4. Local setup — the gotchas the page can't know

The page assumes a clean sibling-clone layout. Ours isn't, and shadows' won't be either.

**Repos as siblings.** `gen-compdocs/go.mod` carries a *relative* replace directive
(`../../../../k8s.io/kubernetes`). If your clones aren't directly under a `k8s.io/` directory, that
path doesn't resolve. On my machine the fix is a symlink:

```shell
ln -s ~/Documents/open-source-projects/kubernete/k8s.io \
      ~/Documents/open-source-projects/k8s.io
```

Tell shadows this up front. It presents as a baffling Go module error, not as a path problem, and
it's the single most likely thing to stall someone on day one.

**Version matching.** The `kubernetes` checkout has to match the version pinned in
`gen-compdocs/go.mod`. Check the `k8s.io/kubectl` version there, then check out the matching tag.
Mismatched versions produce output that builds fine and is quietly wrong.

**Tooling for `updateapispec-enums-from-source`:** `jq`, `curl`, `openssl`, network access, and free
TCP **2379** (etcd) and **8050** (temporary API server). Override with `ETCD_PORT` / `API_PORT`. It
downloads etcd and builds `kube-apiserver`, so the first run takes several minutes — that's normal,
not a hang.

**Keep the temp checkout when debugging:** `KEEP_TMP=1 make updateapispec-enums-from-source`.

**Confirmed present on my machine** (2 Sep): all three repos, the symlink, `hack/verify-enum-swagger.sh`,
every `make` target the page names, and `jq`/`curl`/`openssl`/`go`/`make`. `gen-apidocs/config/`
currently ends at `v1_36`, so `v1_37` and `v1_38` both get created this cycle.

---

## 5. The one step that isn't automated

Everything about the *API surface* is auto-detected: the build targets pass `--auto-detect`, so
`gen-apidocs` reads API groups and resources straight from `swagger.json`. New resources appear
without anyone touching config.

**`genref` is different.** It generates one page per entry in `genref/config.yaml`, and each entry
names a Go package and a version path by hand:

```yaml
  - name: kubelet-config
    title: Kubelet Configuration (v1)
    package: k8s.io/kubelet
    path: config/v1
```

If a component starts serving a new configuration API version in v1.38 and nobody adds the entry,
**that page simply doesn't exist** and nothing fails. No error, no warning — a missing page.

The page carries a shell loop that compares every `config.yaml` entry against the version
directories in the source. Run it during the **rehearsal**, not in December:

```shell
cd <rdocs-base>/genref && go mod download
# ...the awk/find loop from the page's "Check for new API versions" section
```

Every line it prints is a *candidate*, not a gap. Several older versions are excluded deliberately
and the comments in `config.yaml` say why. Judgement: add an entry when a component serves a version
readers actually configure; keep an older entry while the component still serves it. That's the
call I'm keeping in Pair C.

---

## 6. When the output looks wrong

Shadows will find rendering bugs and assume the generator is at fault. Usually it isn't. **Diagnose
in this order:**

1. **`grep "the broken text" gen-apidocs/config/v1_38/swagger.json`.** If the bug is already in the
   swagger, it's upstream in `kubernetes/kubernetes` — nothing downstream can fix it correctly.
2. If the swagger is clean, look at the generator: `markdown.go`, `resource.tmpl`, the escape function.
3. If both look right, it's the Hugo template or Docsy.

Two known bugs, so nobody re-investigates them:

| Symptom | Actually caused by | Fix belongs |
|---|---|---|
| Literal `*` in prose instead of a bullet list — *"X binds together: * a * b * c"* | `fmtRawDoc` in `apimachinery/pkg/runtime/swagger_doc_generator.go` joins multi-line Go doc comments with a space, dropping the newlines before swagger is written | **Upstream in k/k.** Don't try to re-inject newlines downstream — too many false positives (`"matches: foo *bar* baz"`, globs, multiplication). Visible on production today. |
| Resource name appears twice — `<h1>` from frontmatter, `<h2>` from the body | `gen-apidocs/generators/templates/resource.tmpl` always emits `## {{.Title}}` for the root section, but Docsy already renders the title | **In reference-docs.** Special-case the first section to emit only `<a name="...">`, preserving the anchor. Sub-sections keep `##`. Small template edit. |

**And the hard rule:** never hand-edit a generated page. The next release overwrites it. Fix it
upstream in k/k, or in the generator.

---

## 7. Three backends, none deprecated

Shadows reading the Makefile will find `api`, `apimd`, and `apimd-hugo` and assume one is legacy.
None are:

- **`html`** (`make api` / `copyapi`) — powers the production single-page API reference at
  `kubernetes.io/docs/reference/generated/kubernetes-api/v1.38/`. This is live production output.
- **`markdown`** (`make apimd` / `copyapimd`) — Hugo-native pages under
  `content/en/docs/reference/kubernetes-api/`.
- **`hugo-md`** (`make apimd-hugo`) — opt-in variant where selected tables emit as markdown tables
  with `{class="..."}` so website render hooks can enrich them. Output to `gen-apidocs/build/hugo-md/`.
  Part of the shortcodes rollout, **not** part of the v1.38 release generation.

For this cycle: `copyapi` and `copyapimd` only. Leave `apimd-hugo` out of the release path.

---

## 8. PR descriptions

Every website PR says how the output was produced, so a reviewer can reproduce it:

```text
Regenerated the kubectl reference for v1.38.0.

- Generated with `make copycomp-kubectl` from kubernetes-sigs/reference-docs at commit <commit>
- Generator changes: kubernetes-sigs/reference-docs#<pull request>
- Generated files only, with no hand edits
```

For the two API sets, add how the swagger was produced — *generated from source with
`OpenAPIEnums=true`*, or copied from a clone. The generated output doesn't reveal which, and it
changes whether enum values are present.

**Verify the enums landed.** Open a resource such as Pod in the preview and search for
`Possible enum values`. If it's absent, the swagger was the committed one and the whole API
reference is quietly missing every enumerated field's allowed values.

---

## 9. What "done" means

- [ ] #57160 merged, or shadows have the preview link — by **Fri 30 Oct**
- [ ] Rehearsal complete at `beta.0`, findings in [log.md](../log.md) — week 10
- [ ] `genref/config.yaml` checked for new config API versions — week 10, not December
- [ ] `v1_38` config dir created; swagger prepped; `verify-enum-swagger.sh` passes
- [ ] Six website PRs against `dev-1.38`, three reference-docs PRs, each website PR held behind its generator PR
- [ ] `Possible enum values` present in the HTML API reference
- [ ] Generated page count sane vs v1.37; no config-api page silently vanished
- [ ] All nine merged before the **Tue 15 Dec** freeze
- [ ] **Each pair ran their own generator end to end without me driving it** — the actual goal

That last box is why we're doing it this way. Reference generation has been a single-person
dependency for three cycles. If two pairs can run it unaided by December, it stops being one.
