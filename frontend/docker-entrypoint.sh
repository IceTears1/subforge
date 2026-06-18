#!/bin/sh
set -e

# Generate nginx config from template using envsubst
# Only replace our custom variables, leave nginx $variables untouched

if [ -n "$DOMAIN" ] && [ -f /etc/nginx/nginx-ssl.conf.template ]; then
    # SSL mode: use SSL template with domain
    envsubst '$BACKEND_PORT $DOMAIN' < /etc/nginx/nginx-ssl.conf.template > /etc/nginx/nginx.conf
    echo "Nginx SSL config generated for domain: ${DOMAIN}"
else
    # HTTP mode: use standard template
    if [ -f /etc/nginx/nginx.conf.template ]; then
        envsubst '$BACKEND_PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
        echo "Nginx config generated with BACKEND_PORT=${BACKEND_PORT:-8081}"
    fi
fi

# Execute nginx directly (skip original entrypoint to avoid recursion)
exec "$@"
