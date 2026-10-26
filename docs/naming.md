# Claiming the dodo name

Checked 2026-10-26.

| Where | Name | Status | How it gets claimed | Who |
|---|---|---|---|---|
| GitHub org | `dodo-mojo` | **Free** | Create at https://github.com/account/organizations/new (Free plan). GitHub has no API for personal accounts to create orgs. | You (web UI) |
| GitHub repo | `dodo-mojo/dodo` | Free once the org exists | `gh repo create dodo-mojo/dodo --public`, then push | Claude, after the org exists |
| Docs site | `dodo-mojo.github.io` | Comes with the org | GitHub Pages from the repo | Claude, later |
| Mojo packages (modular-community channel, prefix.dev) | `dodo` | **Free** | A PR to [modular/modular-community](https://github.com/modular/modular-community) adding `recipes/dodo/recipe.yaml`. It must point to a real tagged release that builds and passes tests, so empty placeholders aren't possible. Plan: publish `0.0.1` as soon as a minimal server works (early Phase 1). | Claude prepares, you approve |
| conda-forge | `dodo` | Free | Not needed. Mojo users install from modular-community. | — |
| PyPI | `dodo` | **Taken** (DigitalOcean CLI) | — | — |
| PyPI | `dodo-mojo` | Free | Only if we ship a pip-installable CLI wrapper. PyPI discourages placeholder uploads, so claim it with a real release. | Later |
| npm, crates.io | `dodo` | Taken | Not needed. | — |
| Domains | `dodo.dev`, `getdodo.dev` | Registered | — | — |
| Domains | `dodo.run`, `dodo.app` ($79,999 aftermarket), most `dodo.*` | Taken or premium | — | — |
| Domains | `dodomojo.dev` ($8.75, renews $12.87), `usedodo.dev` (same), `dodomojo.com` ($11.08) | **Available** at Porkbun | Buy later. Not required: `dodo-mojo.github.io` works for docs. | You |
| X | `@dodo_mojo` free, `@dodomojo` taken | Checked | Optional | You |
| Bluesky | `dodomojo.bsky.social` free, `dodo.bsky.social` taken | Checked | Optional | You |
| YouTube | `@dodo-mojo` free, `@dodomojo` taken | Checked | Optional | You |
| Discord | — | Can't be checked publicly | Create a server when there are users | You |

## Name conflicts

Other things called "Dodo": Dodo Payments (fintech), Dodo Brands (pizza), Dodo (Australian ISP), and the PyPI `dodo` CLI. All are different fields, and "dodo-mojo" plus "web framework" separates us clearly in search. This isn't legal advice. Before 1.0, a quick trademark search for software in your country is worth doing.

## The CLI binary

The `dodo` command could collide with the PyPI `dodo` DigitalOcean tool if someone has both installed. That's rare. If it happens, the fix is a `dodo-mojo` alias, not a rename.
