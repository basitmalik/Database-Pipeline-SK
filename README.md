# Secure DB CI/CD Pipeline (GitHub Actions + PostgreSQL in Docker)

Secure pipeline that deploys SQL changes to a PostgreSQL database running in a
Docker container on the server, via a self-hosted GitHub Actions runner —
with a DELETE/TRUNCATE guard, automatic DDL-vs-DML routing, full logs, and
one-click rollback.

## How it works

```
push to main (sql/** changed)
        │
        ▼
┌─────────────────────────────┐
│ 1. GUARD                    │  Scans the DML file. If it contains
│    check_forbidden.sh       │  DELETE or TRUNCATE → pipeline FAILS with
└─────────────────────────────┘  "DELETE/TRUNCATE detected". Nothing runs.
        │ pass
        ▼
┌─────────────────────────────┐
│ 2. DETECT                   │  Reads the table name from the CREATE TABLE
│    extract_tables.sh        │  in file 1, asks Postgres if it exists.
└─────────────────────────────┘
        │
   ┌────┴─────────────────┐
   ▼ table missing        ▼ table exists
┌──────────────┐   ┌──────────────────────────────┐
│ 3a. Run DDL  │   │ 3b. BACKUP SNAPSHOT           │
│  (file 1)    │   │  CREATE TABLE bak_<t>_<run>   │
└──────────────┘   │  AS TABLE <t>                 │
                   └──────────────────────────────┘
                          │
                          ▼
                   ┌──────────────┐
                   │ 3c. Run DML  │
                   │  (file 2)    │
                   └──────────────┘
```

Every run writes a **job summary** (Actions → run page) and uploads the raw
psql output as an **artifact** (kept 30 days).

**Rollback:** Actions → "DB Rollback" → Run workflow. Restores the table from
the latest snapshot (or a specific one, e.g. `bak_employees_42`). The restore
runs in a single transaction — if it fails midway nothing changes.

## Setup

### 1. Self-hosted runner (on the server that runs the Postgres container)

Repo → Settings → Actions → Runners → New self-hosted runner, follow the
commands, then install it as a service:

```bash
sudo ./svc.sh install && sudo ./svc.sh start
```

The runner user must be in the `docker` group.

### 2. GitHub Secrets (Settings → Secrets and variables → Actions → Secrets)

| Secret        | Example    | Notes                                        |
|---------------|------------|----------------------------------------------|
| `DB_USER`     | `appuser`  | App user — **not** the `postgres` superuser  |
| `DB_PASSWORD` | `********` | Masked automatically in all logs             |

### 3. GitHub Variables (same page → Variables tab)

| Variable       | Example |
|----------------|---------|
| `PG_CONTAINER` | `pg-db` |
| `DB_NAME`      | `appdb` |

### 4. File paths

Edit the top of `.github/workflows/db-deploy.yml` if your SQL files are named
differently:

```yaml
env:
  DDL_FILE: sql/01_create_table.sql   # file 1 - CREATE TABLE
  DML_FILE: sql/02_dml.sql            # file 2 - INSERT / UPDATE
```

## Security properties

- **No DB port exposed to the internet** — Postgres binds to `127.0.0.1` on the
  server; the self-hosted runner talks to Docker locally.
- Credentials live only in GitHub Secrets; GitHub masks them in every log line.
- The pipeline connects as a **least-privilege app user**, not `postgres`.
- Guard strips comments/string literals first, so `-- delete later` or a
  `deleted_at` column won't false-positive, but real statements can't hide
  behind casing (`DeLeTe`) or extra whitespace.
- `--single-transaction` — a failing SQL file never half-commits.
- `concurrency: db-pipeline` — deploy and rollback can never run simultaneously.
- Snapshots auto-prune: only the last 5 per table are kept (`BACKUP_KEEP`).

## Limitations to know

- Snapshots copy **data**, not indexes/constraints — rollback restores rows
  into the existing table (DELETE + INSERT), it does not recreate the table.
- The guard blocks `DELETE`/`TRUNCATE`. Add `DROP|ALTER` to the `FORBIDDEN`
  regex in `scripts/check_forbidden.sh` to block those too.
