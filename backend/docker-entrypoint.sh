#!/bin/sh
set -e

echo "Waiting for database..."
# The docker-compose healthcheck handles this, but just in case
sleep 2

echo "Starting SubForge..."
exec ./subforge
