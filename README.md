# Aspen Discovery — Local Dev Environment

A Docker Compose setup for developing [Aspen Discovery](https://github.com/Aspen-Discovery/aspen-discovery) locally against an external ILS.
Built on top of the prod `docker/` setup in the main repo, with two changes:

1. Your local clone is **bind-mounted** over `/usr/local/aspen-discovery` — edits in
   your IDE are live instantly, no rebuild needed.
2. Optional **Xdebug** support via `host.docker.internal`.

---

## Directory structure

Place this folder next to your cloned repo:

```
~/Git/
  aspen-discovery/        ← your fork/clone
  aspen-dev-local/        ← this folder
    .env.example
    .env                  ← your copy (git-ignored)
    build.sh              ← first-time build script
    docker-compose.yml
    Dockerfile.dev
    dev-init.sh
    xdebug.ini
    sites/                ← created automatically on first run
      {SITE_NAME}/
        conf/             ← generated site config
        data/             ← covers, MARC, uploads, etc.
        logs/             ← Apache + Aspen logs
```

---

## First-time setup

### 1. Create your `.env`

```bash
cp .env.example .env
```

Edit `.env` and set at minimum:

| Variable | What to set |
|---|---|
| `ASPEN_REPO_PATH` | Absolute path to your local clone |
| `SITE_NAME` | Your dev site name (e.g. `dev.localhost`) |
| `URL` | `http://localhost` (or your OrbStack domain) |
| `TIMEZONE` | Your timezone |
| `ASPEN_ADMIN_PASSWORD` | Whatever you want for the admin UI |

Everything else has working defaults.

### 2. Build and start

The first build takes a while (10–15 minutes on first run) because it compiles the full Aspen image. Use the provided script which handles the build order correctly:

```bash
chmod +x build.sh
./build.sh
```

This will build the base image, then the dev image on top, bring everything up, and tail the backend logs. Wait for:

```
Starting PHP-FPM in foreground mode...
```

Then open **http://localhost** and log in with `aspen_admin`.

### 3. Connect your ILS

After first boot you have a working Aspen instance with no ILS connection. You have two options:

#### Option A — Import an existing Aspen database

If you have a database export from another Aspen instance (e.g. your prod or staging environment), you can import it directly:

```bash
# Import into the running db container
docker compose exec -T db mariadb -u aspendev -paspendev aspen < your-export.sql
```

#### Option B — Configure from scratch

If you're starting fresh, you need to do four things in the Aspen admin UI in order:

1. **Create an Account Profile** — go to *ILS → Account Profiles* and add your ILS connection details.

2. **Create an Indexing Profile** — go to *ILS → Indexing Profiles* and configure it to point at your ILS. Make sure the record source matches your account profile.

3. **Enable your ILS Module** — go to *System Administration → Modules* and make sure your ILS module (e.g. Koha) is enabled. This step actually kicks off background indexing and loading in default Translation Maps.

Once the module is enabled, the background process manager runs every 5 minutes via cron and will start the indexer automatically. 

---

## Daily use

```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f backend
docker compose logs -f cron

# Shell into the app container
docker compose exec backend bash
```

Code changes to PHP/JS/templates are live immediately. No restart needed.

---

## Services & ports

| Service | URL | Notes |
|---|---|---|
| Aspen | http://localhost | Main UI — port set by `HTTP_PORT` |
| Adminer | http://localhost:8080 | Database GUI — port set by `DB_GUI_PORT` |
| Solr | http://localhost:8983 | Search admin — port set by `SOLR_PORT` |

**Adminer login:**
- Server: `db`
- Username / Password: your `DATABASE_USER` / `DATABASE_PASSWORD`
- Database: `aspen`

---

## Enabling Xdebug

In `.env`, set `XDEBUG_ENABLE=true`, then recreate the backend:

```bash
docker compose up -d --force-recreate backend
```

**PhpStorm:** Settings → PHP → Debug → confirm port matches `XDEBUG_CLIENT_PORT` (default `9003`). Start listening, then load a page.

**VS Code:** Install the *PHP Debug* extension. In `launch.json`:
```json
{ "name": "Listen for Xdebug", "type": "php", "request": "launch", "port": 9003 }
```

To disable, set `XDEBUG_ENABLE=false` and force-recreate again. The extension stays installed in the image but goes inactive.

---

## Rebuilding images

Only needed when `docker/Dockerfile` changes in the repo (new PHP extensions, base OS bump, etc.). Use the same build script:

```bash
docker compose down
docker rmi aspen-dev-local aspen-dev-local-base aspen-solr-local
rm -rf ./sites/
./build.sh
```

> [!NOTE]
> A full reset re-initializes the database from the seed SQL in your repo. If you're on a beta release and things like loading the default database error out, initialize on an earlier stable commit first, get things up and running, run database updates, then switch back to your target commit and restart.

## Full reset

> [!IMPORTANT]
> Wipes all containers, volumes, and site data.

```bash
docker compose down -v
docker rmi aspen-dev-local aspen-dev-local-base aspen-solr-local
rm -rf ./sites/
```
