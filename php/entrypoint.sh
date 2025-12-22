#!/bin/sh
set -e

if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "⚡ Installing WordPress..."
    rm -rf /var/www/html/*
    curl -o wordpress.tar.gz -fL "https://wordpress.org/latest.tar.gz"
    tar -xzf wordpress.tar.gz -C /var/www/html --strip-components=1
    rm wordpress.tar.gz
    cp wp-config-sample.php wp-config.php

    # Configurazione DB
    sed -i "s/database_name_here/$DB_NAME/" wp-config.php
    sed -i "s/username_here/$DB_USER/" wp-config.php
    sed -i "s/password_here/$DB_PASS/" wp-config.php
    sed -i "s/localhost/$DB_HOST/" wp-config.php

    # Configurazione Extra
    cat <<EOF >> wp-config.php
define('FS_METHOD', 'direct');
define('WP_REDIS_HOST', '${REDIS_HOST}');
define('WP_REDIS_PORT', ${REDIS_PORT});
define('WP_CACHE', true);

/* Fix SSL per Dokploy/Traefik */
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    \$_SERVER['HTTPS'] = 'on';
}
EOF
fi

exec "$@"
