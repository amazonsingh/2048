# DSpace Docker Deployment

Production-ready Docker configuration for deploying DSpace digital repository system.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Docker Compose Network                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   DSpace    │  │   DSpace    │  │   DSpace    │            │
│  │  Angular    │──│  Backend    │──│    Solr     │            │
│  │  Frontend   │  │ (REST API)  │  │   Search    │            │
│  │  Port:4000  │  │  Port:8080  │  │  Port:8983  │            │
│  └─────────────┘  └──────┬──────┘  └─────────────┘            │
│                          │                                      │
│                   ┌──────┴──────┐                              │
│                   │ PostgreSQL  │                              │
│                   │  Database   │                              │
│                   │  Port:5432  │                              │
│                   └─────────────┘                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Image | Port | Description |
|---------|-------|------|-------------|
| `dspacedb` | `postgres:15` | 5432 | PostgreSQL database |
| `dspacesolr` | `dspace/dspace-solr:latest` | 8983 | Apache Solr search |
| `dspace` | `dspace/dspace:latest-test` | 8080 | REST API backend |
| `dspace-angular` | `dspace/dspace-angular:latest-test` | 4000 | Angular frontend |

## Prerequisites

- Docker 24.0+
- Docker Compose v2
- 8GB+ RAM
- 20GB+ disk space

## Quick Start

### 1. Start All Services

```bash
cd dspace-docker
docker compose up -d
```

### 2. Monitor Startup Progress

```bash
# Watch all logs
docker compose logs -f

# Or watch just the backend
docker logs -f dspace
```

### 3. Wait for Startup

The first startup takes 2-5 minutes as it:
1. Creates Solr cores (7 required cores)
2. Runs database migrations (Flyway)
3. Initializes Spring Boot application

Look for this message in the logs:
```
Started ServerBootApplication in XX seconds
```

### 4. Access DSpace

- **REST API**: http://localhost:8080/server/api
- **Angular UI**: http://localhost:4000
- **Solr Admin**: http://localhost:8983/solr

## Commands

```bash
# Start all services
docker compose up -d

# Stop all services (keeps data)
docker compose down

# Stop and remove all data
docker compose down -v

# View logs
docker compose logs -f [service_name]

# Restart a service
docker compose restart dspace

# Check service health
docker ps
```

## Configuration

### Environment Variables

Configure in `docker-compose.yml` or create a `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `db__P__url` | `jdbc:postgresql://dspacedb:5432/dspace` | Database JDBC URL |
| `db__P__username` | `dspace` | Database user |
| `db__P__password` | `dspace` | Database password |
| `solr__P__server` | `http://dspacesolr:8983/solr` | Solr server URL |
| `dspace__P__name` | `DSpace Repository` | Site name |

### Local Configuration

Edit `local.cfg` to customize DSpace settings:

```properties
# Site name
dspace.name = My Digital Library

# URLs (for production, use your actual domain)
dspace.server.url = https://api.example.com/server
dspace.ui.url = https://library.example.com
```

## Solr Cores

DSpace requires 7 Solr cores. These are created automatically on first startup:

| Core | Purpose |
|------|---------|
| `search` | Main discovery/search |
| `authority` | Authority control |
| `oai` | OAI-PMH harvesting |
| `statistics` | Usage statistics |
| `qaevent` | Quality assurance events |
| `suggestion` | Suggestions/corrections |
| `audit` | Audit logging |

## Volumes

Data is persisted in Docker volumes:

| Volume | Purpose |
|--------|---------|
| `pgdata` | PostgreSQL database files |
| `solr_data` | Solr index data |
| `assetstore` | Uploaded files/bitstreams |

## Troubleshooting

### Container Exits Immediately

Check the logs for the actual error:
```bash
docker logs dspace 2>&1 | tail -100
```

Common causes:
1. **Solr not ready**: DSpace requires Solr to be accessible at startup
2. **Database not ready**: PostgreSQL must accept connections
3. **Missing config**: Check `local.cfg` has correct hostnames

### Database Connection Failed

Verify PostgreSQL is running:
```bash
docker exec dspacedb pg_isready -U dspace -d dspace
```

### Solr Connection Failed

Verify Solr cores exist:
```bash
curl http://localhost:8983/solr/admin/cores?action=STATUS
```

### Reset Everything

To start fresh:
```bash
docker compose down -v
docker compose up -d
```

## Production Deployment

For production use, update these settings:

1. **Change passwords** in `docker-compose.yml` and `local.cfg`
2. **Configure SSL** with a reverse proxy (nginx/traefik)
3. **Set proper URLs** in `local.cfg`
4. **Configure email** for notifications
5. **Set up backups** for volumes

### Example Production URLs

```properties
# local.cfg for production
dspace.server.url = https://api.library.example.com/server
dspace.ui.url = https://library.example.com
```

## Key Learnings

This configuration is based on extensive testing with official DSpace Docker images:

1. **Solr must be ready before DSpace starts** - DSpace checks Solr connectivity during Spring Boot initialization
2. **Container hostnames matter** - Use `dspacedb` and `dspacesolr` (no hyphens in service names)
3. **All 7 Solr cores required** - Missing cores will cause startup failures
4. **Database migrations run automatically** - Flyway is integrated into DSpace
5. **Health checks are important** - Use `depends_on` with `condition: service_healthy`

## Files

```
dspace-docker/
├── docker-compose.yml      # Main Docker Compose configuration
├── local.cfg               # DSpace configuration overrides
├── README.md               # This file
└── scripts/
    ├── backend-entrypoint.sh   # DSpace startup script
    └── frontend-entrypoint.sh  # Angular startup script
```

## License

DSpace is open source software, licensed under the BSD license.
