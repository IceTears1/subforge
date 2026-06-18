#!/bin/sh
set -e

# Generate nginx config from template using envsubst
# Only replace our custom variables, leave nginx $variables untouched
if [ -f /etc/nginx/nginx.conf.template ]; then
    # Use envsubst with specific variable list to avoid replacing nginx $variables
    envsubst '$BACKEND_PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
    echo "Nginx config generated with BACKEND_PORT=${BACKEND_PORT:-8081}"
fi

# Execute nginx directly (skip original entrypoint to avoid recursion)
exec "$@"
