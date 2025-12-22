#!/bin/sh
set -e

echo "⚙️  Configuring PHP Limits..."

# 1. Genera custom.ini
cat <<EOF > /usr/local/etc/php/conf.d/custom.ini
[PHP]
memory_limit = ${PHP_MEMORY_LIMIT}
upload_max_filesize = ${PHP_UPLOAD_LIMIT}
post_max_size = ${PHP_POST_LIMIT}
max_execution_time = ${PHP_MAX_TIME}
max_input_time = ${PHP_MAX_TIME}
max_input_vars = ${PHP_MAX_INPUT_VARS}
expose_php = Off

[opcache]
opcache.enable = ${OPCACHE_ENABLE}
opcache.memory_consumption = ${OPCACHE_MEMORY}
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 10000
opcache.validate_timestamps = 1
opcache.revalidate_freq = 2
EOF

# 2. Installa WordPress se manca
if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "⚡ WordPress not found. Installing..."
    
    rm -rf /var/www/html/*
    curl -o wordpress.tar.gz -fL "https://wordpress.org/latest.tar.gz"
    tar -xzf wordpress.tar.gz -C /var/www/html --strip-components=1
    rm wordpress.tar.gz
    
    cp wp-config-sample.php wp-config.php
    
    sed -i "s/database_name_here/$DB_NAME/" wp-config.php
    sed -i "s/username_here/$DB_USER/" wp-config.php
    sed -i "s/password_here/$DB_PASS/" wp-config.php
    sed -i "s/localhost/$DB_HOST/" wp-config.php

    # Config Extra
    cat <<EOF >> wp-config.php

/* --- STACK CONFIG --- */
define('FS_METHOD', 'direct');
define('WP_REDIS_HOST', '${REDIS_HOST}');
define('WP_REDIS_PORT', ${REDIS_PORT});
define('WP_CACHE', true);

/* Disabilita WP-Cron (Gestito da Dokploy/System) */
define('DISABLE_WP_CRON', true);

/* SSL Fix Traefik */
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    \$_SERVER['HTTPS'] = 'on';
}
EOF
    echo "✅ WordPress Installed."
fi

echo "🚀 Starting PHP-FPM..."
exec "$@"
