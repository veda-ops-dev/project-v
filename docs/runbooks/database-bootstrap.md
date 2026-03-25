# Database Bootstrap

## Purpose

This runbook defines the local database bootstrap procedure for Project V.

It exists to answer:

```text
How do we provision and verify the local Project V database on the shared PostgreSQL cluster before migrations and implementation begin?
```

This is an operational procedure.
It is not schema authority.
It does not override:

- `docs/architecture/data/db-boundaries.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`

---

## Current Local Posture

Project V local development uses the shared local PostgreSQL cluster already hosting VEDA.

Current local database naming posture:

- `veda_local`
- `project_v_local`

This matches the architecture posture of one shared PostgreSQL cluster with one database per bounded system.

---

## Local Bootstrap Result

The following local bootstrap has been completed successfully for Project V:

- PostgreSQL service confirmed running
- database created: `project_v_local`
- application user created: `project_v_app`
- database owner set to `project_v_app`
- schema created: `app`
- TCP connectivity confirmed on `localhost:5432`
- login verified as `project_v_app`

---

## Canonical Local Connection String

```env
DATABASE_URL=postgresql://project_v_app:projectv@localhost:5432/project_v_local
```

---

## Service Verification

Run in PowerShell:

```powershell
Get-Service | Where-Object {$_.Name -match 'post'}
```

Expected result:

- PostgreSQL service exists
- service status is `Running`

---

## Local Cluster Inspection

Run in PowerShell:

```powershell
psql -U postgres
```

Then inside `psql`:

```sql
\l
```

Expected local database posture includes:

- `veda_local`
- `project_v_local`

---

## Provisioning Commands

Run these commands one at a time inside `psql` as a sufficiently privileged database user:

```sql
CREATE USER project_v_app WITH PASSWORD 'projectv';
CREATE DATABASE project_v_local;
GRANT ALL PRIVILEGES ON DATABASE project_v_local TO project_v_app;
ALTER DATABASE project_v_local OWNER TO project_v_app;
\c project_v_local
CREATE SCHEMA app AUTHORIZATION project_v_app;
\dn
```

Expected schema list:

- `app`
- `public`

---

## App-User Verification

Exit `psql` and test direct login:

```powershell
psql -U project_v_app -d project_v_local
```

Then inside `psql`:

```sql
\conninfo
\dn
```

Expected result:

- connected to `project_v_local`
- connected as `project_v_app`
- schema `app` exists and is owned by `project_v_app`

---

## Important Operating Rules

### 1. Use one database per bounded system

Do not reuse `veda_local` for Project V tables.

### 2. Use the app schema intentionally

Migration 001 should target the `app` schema intentionally.

Do not casually place canonical Project V tables into `public`.

### 3. Keep credentials out of authority docs

The connection string belongs in local environment configuration and operational runbooks, not architecture authority docs.

### 4. One command per line in `psql`

Especially for `psql` meta-commands:

- `\c`
- `\dn`
- `\l`
- `\q`
- `\r`

Do not concatenate them with SQL commands on one line.

### 5. Clear the `psql` input buffer if needed

If the prompt changes to `->` because of unfinished input, clear it with:

```sql
\r
```

---

## Migration Preparation Rule

Before Migration 001 begins, the following must all be true:

- `project_v_local` exists
- `project_v_app` can log in successfully
- schema `app` exists
- local `DATABASE_URL` is known
- implementation work targets the Project V database, not VEDA

---

## Final Rule

Project V migration and hammer work begins only after the local database boundary is provisioned, reachable, and verified.
