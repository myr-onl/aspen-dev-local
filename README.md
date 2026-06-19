# Aspen Discovery — Local Dev Environment

A Docker Compose setup for developing [Aspen Discovery](https://github.com/Aspen-Discovery/aspen-discovery) locally against an external ILS.
Built on top of the prod `docker/` setup in the main repo, with two key changes:

1. Your local clone is **bind-mounted** over `/usr/local/aspen-discovery`, meaning edits in
   your IDE are live instantly, no rebuild needed.
2. Optional **Xdebug** support via `host.docker.internal`.

## Directory structure

Place this repo next to your cloned Aspen Discovery repo. For example:

```
aspen-discovery/         ← your fork/clone
aspen-dev-local/         ← this repo
├── .env.example
├── .env                 ← your copy (git-ignored)
├── build.sh             ← first-time build script
├── docker-compose.yml
├── Dockerfile.dev
├── dev-init.sh
├── xdebug.ini
└── sites/
    └── {SITE_NAME}/     ← created automatically on first run
        ├── conf/        ← generated site config
        ├── data/        ← covers, sideload MARC, uploads, etc.
        └── logs/        ← Apache + Aspen logs
```

## First-time setup

### 1. Create your `.env`

```bash
cp .env.example .env
```

Edit `.env` and set at minimum:

| Variable               | What to set                                                                   |
|------------------------|-------------------------------------------------------------------------------|
| `ASPEN_REPO_PATH`      | Absolute path to your local clone (include `C:\` info on Windows)             |
| `SITE_NAME`            | Your dev site name (e.g., `dev.localhost`)                                    |
| `URL`                  | Local hostname where the site will be accessed (e.g., `http://localhost`)     |
| `TIMEZONE`             | Your timezone (see [PHP Manual](https://www.php.net/manual/en/timezones.php)) |
| `ASPEN_ADMIN_PASSWORD` | Whatever you want to use to sign in as the `aspen_admin` superadmin account   |

Everything else has working defaults.

### 2. Build and start

Use the provided script, which handles the build order correctly.

```bash
chmod +x build.sh
./build.sh
```

This will build the base image, then the dev image on top, bring everything up, and tail the backend logs. Wait for: `Starting PHP-FPM in foreground mode...` before doing anything.

> [!NOTE]
> The first build can take a while (10–15 minutes on first run) because it downloads and compiles all component parts into the full Aspen image.

Then open **http://localhost** and log in with `aspen_admin`.

### 3. Connect your ILS

After first boot you have a working Aspen instance with no ILS connection. You have two options.

#### Option A: Import an existing Aspen database

If you have a database export from another Aspen instance (e.g., your prod environment), you can import it directly:

```bash
# Import into the running db container
docker compose exec -T db mariadb -u aspendev -paspendev aspen < your-export.sql
```

#### Option B: Configure from scratch

If you're starting fresh, you need to do four things in the Aspen admin UI:

1. **Create an Account Profile**. Go to *ILS → Account Profiles* and add your ILS connection details.

2. **Create an Indexing Profile**. Go to *ILS → Indexing Profiles* and configure it to point at your ILS. Make sure the record source matches your account profile.

3. **Enable your ILS Module**. Go to *System Administration → Modules* and make sure your ILS's module is enabled. This step is what actually kicks off background indexing and loading in default Translation Maps.

The background process manager runs every 5 minutes via cron and will start the indexer automatically.

## Daily use
> [!TIP]
> Code changes should be live immediately on save. No restart or rebuild needed.

### Start
```bash
docker compose up -d
```

### Stop
```bash
docker compose down
```

### View Logs
```bash
docker compose logs -f backend
docker compose logs -f cron
```

### Shell into app container
```bash
docker compose exec backend bash
```

## Services & ports

| Service | Description            | Port variable | Default URL           |
|---------|------------------------|---------------|-----------------------|
| Aspen   | Main UI                | `HTTP_PORT`   | http://localhost      |
| Adminer | Database GUI           | `DB_GUI_PORT` | http://localhost:8080 |
| Solr    | Search admin dashboard | `SOLR_PORT`   | http://localhost:8983 |

**Adminer login:**
- Server: `db`
- Username: `DATABASE_USER`
- Password: `DATABASE_PASSWORD`
- Database: `aspen`


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


## Rebuilding images

You should only need to rebuild when there are `docker/Dockerfile` changes in the main repo (new PHP extensions, base OS bump, etc.). Use the same build script:

```bash
docker compose down
docker rmi aspen-dev-local aspen-dev-local-base aspen-solr-local
./build.sh
```

## Full reset

> [!WARNING]
> Wipes all containers, volumes, **and** site data.

```bash
docker compose down -v
docker rmi aspen-dev-local aspen-dev-local-base aspen-solr-local
rm -rf ./sites/
```
