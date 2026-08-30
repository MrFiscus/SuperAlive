# supabase-inactivityfix

Keeps free-tier Supabase projects from being **paused after 7 days of inactivity**.

Same idea as [travisvn/supabase-pause-prevention](https://github.com/travisvn/supabase-pause-prevention),
but with **no Vercel / Next.js app** — a scheduled **GitHub Actions** workflow pings
every project's database on a cron. One workflow keeps any number of projects alive.

## How it works

```
Your fork of this repo  ──cron every 3 days──>  pings each Supabase project
```

1. Each Supabase project gets a tiny `keep-alive` table.
2. Every 3 days, [`.github/workflows/keep-alive.yml`](.github/workflows/keep-alive.yml)
   runs [`scripts/keep-alive.sh`](scripts/keep-alive.sh).
3. The script does one PostgREST read per project against `keep-alive`, using a
   **random filter value** each time so nothing can serve it from cache.
4. That request counts as activity, so the 7-day pause timer never fires.

The setup page under [`setup/`](setup/) is **only a config generator** — it runs
entirely in your browser and keeps nothing alive by itself. The work is done by the
Action, which has to live in a repo you own.

## Setup

### 1. Get your own copy of this repo

**Fork it**, or click **Use this template**. This step is not optional — the workflow
runs on your account's Actions minutes and reads a secret stored on your repo.

### 2. Enable Actions on your copy

Open the **Actions** tab and confirm the prompt. GitHub disables workflows in forks by
default, scheduled ones included, so nothing runs until you do this.

### 3. Run the setup page

Open [`setup/index.html`](setup/index.html) — double-click the file, or host it (see
[GitHub Pages](#hosting-the-setup-ui-optional)). It walks you through the SQL to run,
a form to add each project with a live **Test connection** button, and the exact secret
value to copy. Your keys never leave the browser.

Prefer to do it by hand? See [Manual setup](#manual-setup) below.

### 4. Save the secret

Paste the generated config into `targets.json` (gitignored), then:

```bash
gh secret set SUPABASE_KEEPALIVE_TARGETS < targets.json
```

Or: **Settings → Secrets and variables → Actions → New repository secret**,
named `SUPABASE_KEEPALIVE_TARGETS`.

### 5. Verify

**Actions → SuperAlive → Run workflow.** The log should show `✓` per project.
After that it's hands-off.

## Manual setup

**1. Create the table in every project** — in each project's **SQL Editor**, run
[`sql/keep-alive.sql`](sql/keep-alive.sql).

**2. Collect connection info** — for each project, from **Settings → API**, grab the
**Project URL** (`https://<ref>.supabase.co`) and the **`service_role` key**. Build a
JSON array (see [`targets.example.json`](targets.example.json)):

```json
[
  { "name": "project-one", "url": "https://aaaa.supabase.co", "key": "eyJ...role_1..." },
  { "name": "project-two", "url": "https://bbbb.supabase.co", "key": "eyJ...role_2..." }
]
```

> Prefer the **anon** key? Use it instead, but then uncomment the RLS policy
> block in `sql/keep-alive.sql` for that project. See [Security](#security).

**3.** Save it as the secret and verify, as in steps 4–5 above.

## Hosting the setup UI (optional)

Push to `main` and enable **Settings → Pages → Source: GitHub Actions**. The
[`pages.yml`](.github/workflows/pages.yml) workflow publishes `setup/` to
`https://<you>.github.io/<repo>/`.

The page is static and stateless, so a hosted copy is safe to share — anyone opening it
generates their own config in their own browser. They still need their own fork and
their own secret; a hosted page can't do that part for them.

## Adding / removing a project

Run `sql/keep-alive.sql` in the new project, then update the
`SUPABASE_KEEPALIVE_TARGETS` secret with the new JSON. No code changes.

## Security

Where your keys actually go:

- **The setup page** has no backend. Keys are saved to your browser's `localStorage`
  (unencrypted, on your own disk) and sent over HTTPS only to your own `*.supabase.co`
  project when you press **Test connection**.
- **The secret** is encrypted at rest and injected only into workflow runs. Anyone with
  write access to your repo can read it — true of every GitHub secret. Fork PRs never
  receive secrets.
- **The logs stay clean**: `keep-alive.sh` passes the key in `curl` headers only, never
  echoes it, and doesn't use `set -x`. Note that GitHub masks a secret's *exact* value,
  so an individual key nested inside the JSON would not be auto-redacted if it ever did
  leak into output.
- **`targets.json` is gitignored** but is plaintext on disk — don't sync it somewhere public.

**Consider using the `anon` key instead of `service_role`.** `service_role` bypasses Row
Level Security entirely — full read/write on every table — which is far more than a
keep-alive ping needs. The `anon` key is designed to be public, and with the RLS policy
in `sql/keep-alive.sql` enabled it can do exactly one thing: read the `keep-alive` table.

## Caveats

- **GitHub disables scheduled workflows after 60 days with no commits to the repo.**
  Any push resets that. If you rarely touch this repo, either push occasionally
  or add a second scheduled job that commits a timestamp file.
- Cron timing on GitHub Actions is best-effort and can be delayed under load —
  the 3-day interval leaves a wide margin before the 7-day limit.

## Licence

MIT — see [LICENSE](LICENSE).

## Local run

```bash
export SUPABASE_KEEPALIVE_TARGETS="$(cat targets.json)"
bash scripts/keep-alive.sh
```

Requires `bash`, `curl`, and `jq`.
