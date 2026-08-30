# SuperAlive

Keeps free-tier Supabase projects from being **paused after 7 days of inactivity**.

A scheduled GitHub Action pings each of your databases every 3 days. No server, no
Vercel app. One workflow handles any number of projects.

## Setup

1. **Fork this repo.** The workflow runs on your account and reads a secret on your repo.
2. **Enable Actions** on your fork. GitHub disables workflows in forks by default.
3. **Open [`setup/index.html`](setup/index.html)** in your browser. It gives you the SQL to
   run in each project, tests each connection, and generates your config. Keys stay in
   your browser.
4. **Save the config** as a repo secret named `SUPABASE_KEEPALIVE_TARGETS`
   (Settings → Secrets and variables → Actions), or:
   ```bash
   gh secret set SUPABASE_KEEPALIVE_TARGETS < targets.json
   ```
5. **Verify:** Actions → SuperAlive → Run workflow. Expect a `✓` per project.

Adding a project later means running the SQL there and updating that one secret.

## How it works

Each project gets a tiny `keep-alive` table. Every 3 days
[`keep-alive.yml`](.github/workflows/keep-alive.yml) runs
[`keep-alive.sh`](scripts/keep-alive.sh), which does one PostgREST read per project using
a random filter value so nothing can answer it from cache. That read counts as activity.

## Good to know

- **GitHub disables scheduled workflows after 60 days with no commits.** Any push resets it.
- Cron timing is best-effort. The 3-day interval leaves margin before the 7-day limit.
- **Consider the `anon` key over `service_role`.** `service_role` bypasses RLS entirely,
  far more than a ping needs. Uncomment the RLS policy in
  [`keep-alive.sql`](sql/keep-alive.sql) to use `anon` instead.
- `targets.json` is gitignored. Anyone with write access to your repo can read the secret,
  as with every GitHub secret.

## Hosting the setup page (optional)

Enable Settings → Pages → Source: GitHub Actions. [`pages.yml`](.github/workflows/pages.yml)
publishes `setup/` to `https://<you>.github.io/<repo>/`.

## Local run

```bash
export SUPABASE_KEEPALIVE_TARGETS="$(cat targets.json)"
bash scripts/keep-alive.sh
```

Requires `bash`, `curl`, `jq`.

## Licence

MIT. See [LICENSE](LICENSE).
