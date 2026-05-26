#!/bin/bash
# build.sh — first-time build or rebuild from scratch

set -e

echo "Building base Aspen image (this takes a few minutes)..."
docker compose build base

echo "Building dev image..."
docker compose build backend solr

echo "Starting all services..."
docker compose up -d

echo "Done! Tailing backend logs — wait for 'Starting PHP-FPM in foreground mode...'"
docker compose logs -f backend