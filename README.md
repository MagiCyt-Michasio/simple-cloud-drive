# Simple Cloud Drive 3.1.0

Self-hosted file cloud for Debian/Linux. Node.js + Express, vanilla HTML/CSS/JS.

## Install

```bash
npm install
cp .env.example .env
nano .env
npm start
```

Set a strong `ADMIN_PASSWORD` and a random `SESSION_SECRET`. Default port: `1213`. Default data directory: `/home/magic/simple-cloud-drive-data`.

## Data

User files and share metadata are stored outside the source tree. Do not commit `.env`, `storage/`, `files/`, backups, or user uploads.

## Features

- Authenticated file browser
- Upload, folders, rename, move and delete
- Single and ZIP downloads
- Public share links with optional password
- In-panel preview for images, PDF, text, audio and video

This repository contains application source only; install dependencies with `npm install`.