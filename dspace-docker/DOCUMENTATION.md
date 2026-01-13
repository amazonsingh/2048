# DSpace Docker Deployment - Complete Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Configuration](#configuration)
6. [Using the UI](#using-the-ui)
7. [Admin Credentials](#admin-credentials)
8. [Troubleshooting Journey](#troubleshooting-journey)
9. [Key Learnings](#key-learnings)
10. [File Reference](#file-reference)
11. [Commands Reference](#commands-reference)

---

## Overview

This project deploys **DSpace 10** digital repository system using Docker with:
- **Supabase PostgreSQL** as the external managed database
- **Apache Solr** for search functionality
- **Angular** frontend for the user interface

### Current Status
✅ **WORKING** - All services deployed and running with Supabase

---

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
└──────────────────────────┼──────────────────────────────────────┘
                           │ SSL Connection
                           ▼
           ┌───────────────────────────────┐
           │     Supabase PostgreSQL       │
           │   aws-1-ap-northeast-2.       │
           │   pooler.supabase.com:5432    │
           └───────────────────────────────┘
```

### Services

| Service | Image | Port | Description |
|---------|-------|------|-------------|
| `dspace` | `dspace/dspace:latest-test` | 8080 | REST API backend |
| `dspacesolr` | `dspace/dspace-solr:latest` | 8983 | Apache Solr search |
| `dspace-angular` | `dspace/dspace-angular:latest` | 4000 | Angular frontend |
| **Supabase** | External | 5432 | PostgreSQL database |

---

## Prerequisites

- Docker 24.0+
- Docker Compose v2
- 8GB+ RAM
- Supabase account with a project

---

## Quick Start

### 1. Configure Environment

Edit `.env` file with your Supabase credentials:

```bash
cd dspace-docker
nano .env
```

Required variables:
```env
SUPABASE_HOST=aws-1-ap-northeast-2.pooler.supabase.com
SUPABASE_PORT=5432
SUPABASE_DATABASE=postgres
SUPABASE_USER=postgres.your-project-id
SUPABASE_PASSWORD=your-password
```

### 2. Start Services

```bash
docker compose up -d
```

### 3. Wait for Startup

First startup with Supabase takes **3-5 minutes** (database migration).

Monitor progress:
```bash
docker logs -f dspace
```

Look for:
```
Started ServerBootApplication in XX seconds
```

### 4. Create Admin Account

```bash
docker exec dspace /dspace/bin/dspace create-administrator \
  -e admin@dspace.local \
  -f Admin \
  -l User \
  -p admin123 \
  -c en
```

### 5. Access DSpace

| Service | URL |
|---------|-----|
| **Web UI** | http://localhost:4000 |
| **REST API** | http://localhost:8080/server/api |
| **Solr Admin** | http://localhost:8983/solr |

---

## Using the UI

### Access the Web Interface

1. Open your browser to: **http://localhost:4000**

2. You'll see the DSpace homepage with:
   - Search bar
   - Browse by communities/collections
   - Recent submissions

### Login as Administrator

1. Click **"Log In"** (top right corner)
2. Enter credentials:
   - **Email**: `admin@dspace.local`
   - **Password**: `admin123`
3. Click **"Log In"**

### Admin Features

Once logged in as admin, you can:

- **Create Communities**: Admin → Communities → New Community
- **Create Collections**: Navigate to a community → New Collection
- **Submit Items**: Navigate to a collection → Submit Item
- **Manage Users**: Admin → Access Control → People
- **Configure Site**: Admin → Site Administrator

### First Steps After Login

1. **Create a Community**:
   - Go to Admin menu → Communities & Collections
   - Click "Create Community"
   - Enter name (e.g., "Research Papers")
   - Save

2. **Create a Collection**:
   - Navigate to your community
   - Click "Create Collection"
   - Enter name (e.g., "2024 Publications")
   - Save

3. **Submit an Item**:
   - Navigate to a collection
   - Click "Submit Item"
   - Fill in metadata (title, author, etc.)
   - Upload file(s)
   - Complete submission workflow

---

## Admin Credentials

### Default Admin Account

| Field | Value |
|-------|-------|
| Email | `admin@dspace.local` |
| Password | `admin123` |
| First Name | Admin |
| Last Name | User |

### Create Additional Admins

```bash
docker exec dspace /dspace/bin/dspace create-administrator \
  -e newadmin@example.com \
  -f FirstName \
  -l LastName \
  -p SecurePassword123! \
  -c en
```

### Reset Password

If you forget the password, create a new admin account or use:
```bash
docker exec -it dspace /dspace/bin/dspace user --modify \
  -e admin@dspace.local \
  -p newpassword
```

---

## Configuration

### Environment Variables (.env)

```env
# Supabase Database
SUPABASE_HOST=aws-1-ap-northeast-2.pooler.supabase.com
SUPABASE_PORT=5432
SUPABASE_DATABASE=postgres
SUPABASE_USER=postgres.your-project-id
SUPABASE_PASSWORD=your-password

# DSpace Settings
DSPACE_NAME=My Digital Library
DSPACE_SERVER_URL=http://localhost:8080
DSPACE_UI_URL=http://localhost:4000

# Admin Account (optional - for auto-creation)
DSPACE_ADMIN_EMAIL=admin@example.com
DSPACE_ADMIN_PASSWORD=SecurePassword123!
```

### Local Configuration (local.cfg)

Key settings in `local.cfg`:
```properties
# Site name
dspace.name = My Digital Library

# URLs (update for production)
dspace.server.url = http://localhost:8080/server
dspace.ui.url = http://localhost:4000

# Database (loaded from environment)
db.driver = org.postgresql.Driver
db.dialect = org.hibernate.dialect.PostgreSQLDialect
```

---

## Troubleshooting Journey

This section documents the issues we encountered and solved during deployment.

### Issue 1: Supabase IPv6 Only

**Problem**: Supabase database returns IPv6 addresses, Docker in Codespaces can't reach IPv6.

**Solution**: Use Supabase connection pooler which provides IPv4 access:
```
aws-1-ap-northeast-2.pooler.supabase.com:5432
```

### Issue 2: Spring Boot Silent Crash

**Problem**: DSpace container exits with code 1 immediately, no error in stdout.

**Root Cause**: DSpace requires Solr to be accessible during Spring Boot initialization.

**Error Found** (in log file):
```
Failed to contact Solr at http://localhost:8983/solr/search
```

**Solution**: Ensure Solr is running and all 7 cores are created BEFORE DSpace starts.

### Issue 3: Missing Solr Cores

**Problem**: DSpace needs 7 Solr cores: authority, oai, search, statistics, qaevent, suggestion, audit.

**Solution**: Custom Solr entrypoint that creates all cores on startup:
```bash
precreate-core search /opt/solr/server/solr/configsets/search
precreate-core authority /opt/solr/server/solr/configsets/authority
# ... etc
```

### Issue 4: Wrong Container Hostnames

**Problem**: Using `dspace-db` and `dspace-solr` as hostnames didn't work.

**Solution**: Use simple names without hyphens: `dspacedb`, `dspacesolr`

### Issue 5: Deprecated Hibernate Dialect

**Problem**: `PostgreSQL94Dialect` not found in DSpace 9/10 (Hibernate 6).

**Solution**: Use `PostgreSQLDialect` instead:
```properties
db.dialect = org.hibernate.dialect.PostgreSQLDialect
```

### Issue 6: Angular REST Host Configuration

**Problem**: Angular configured to connect to `http://dspace:8080` (Docker internal hostname), but browser can't resolve it.

**Solution**: Change `DSPACE_REST_HOST` to `localhost`:
```yaml
DSPACE_REST_HOST: localhost
```

---

## Key Learnings

### 1. Startup Order Matters
DSpace REQUIRES Solr to be fully ready before it starts. Use health checks:
```yaml
depends_on:
  dspacesolr:
    condition: service_healthy
```

### 2. All 7 Solr Cores Are Required
Missing any core causes startup failure:
- search, authority, oai, statistics, qaevent, suggestion, audit

### 3. Environment Variable Format
DSpace uses `__P__` for dots in property names:
```yaml
db__P__url: 'jdbc:postgresql://host:port/db'  # = db.url
```

### 4. SSL for Supabase
Always use `?sslmode=require` for Supabase connections:
```
jdbc:postgresql://host:5432/postgres?sslmode=require
```

### 5. Angular Runs Client-Side
In dev mode, Angular runs in browser, so REST host must be `localhost`, not Docker hostname.

---

## File Reference

```
dspace-docker/
├── .env                    # Environment variables (Supabase credentials)
├── docker-compose.yml      # Main Docker configuration
├── local.cfg               # DSpace configuration overrides
├── README.md               # Quick start guide
├── DOCUMENTATION.md        # This file
├── DEPLOYMENT.md           # Deployment summary
├── Dockerfile.backend      # (Optional) Custom backend build
├── Dockerfile.frontend     # (Optional) Custom frontend build
└── scripts/
    ├── backend-entrypoint.sh    # DSpace startup script
    └── frontend-entrypoint.sh   # Angular startup script
```

### docker-compose.yml Structure

```yaml
services:
  dspacesolr:    # Solr search engine (starts first)
  dspace:        # Backend REST API (waits for Solr)
  dspace-angular: # Frontend UI (waits for backend)
```

---

## Commands Reference

### Basic Operations

```bash
# Start all services
docker compose up -d

# Start without Angular (saves resources)
docker compose up -d dspacesolr dspace

# Stop all services
docker compose down

# View logs
docker compose logs -f
docker logs dspace
docker logs dspacesolr
docker logs dspace-angular

# Restart a service
docker compose restart dspace
```

### Admin Commands

```bash
# Create administrator
docker exec dspace /dspace/bin/dspace create-administrator \
  -e email@example.com -f FirstName -l LastName -p Password -c en

# Reindex Solr
docker exec dspace /dspace/bin/dspace index-discovery -b

# Check database status
docker exec dspace /dspace/bin/dspace database info

# Run database migration
docker exec dspace /dspace/bin/dspace database migrate
```

### Troubleshooting Commands

```bash
# Check container health
docker ps

# Check Solr cores
curl http://localhost:8983/solr/admin/cores?action=STATUS

# Test REST API
curl http://localhost:8080/server/api

# Check Supabase connection
docker exec dspace bash -c 'cat < /dev/null > /dev/tcp/SUPABASE_HOST/5432'

# View DSpace internal logs
docker exec dspace cat /dspace/log/dspace.log
```

### Reset Everything

```bash
# Stop and remove all containers and volumes
docker compose down -v

# Remove Solr data (reindex needed)
docker volume rm dspace-docker_solr_data

# Fresh start
docker compose up -d
```

---

## Production Checklist

Before deploying to production:

- [ ] Change admin password
- [ ] Update URLs in `.env` to use your domain
- [ ] Configure SSL/TLS with reverse proxy
- [ ] Set up database backups
- [ ] Configure email settings
- [ ] Set up monitoring
- [ ] Review security settings
- [ ] Configure persistent storage

### Example Production URLs

```env
DSPACE_SERVER_URL=https://api.library.example.com
DSPACE_UI_URL=https://library.example.com
```

---

## Support

### DSpace Documentation
- Official Docs: https://wiki.lyrasis.org/display/DSDOC
- GitHub: https://github.com/DSpace/DSpace

### Supabase Documentation
- https://supabase.com/docs

---

*Documentation created: January 12, 2026*
*DSpace Version: 10.0-SNAPSHOT*
*Database: Supabase PostgreSQL*
