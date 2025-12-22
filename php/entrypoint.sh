#!/bin/sh
set -e

# --- 1. Fix Permessi ---
chown -R www-data:www-data /var/www/html
if [ -d "/var/cache/nginx" ]; then
    chown -R www-data:www-data /var/cache/nginx
fi

echo "⚙️  Configuring PHP Limits..."

# --- 2. Genera custom.ini ---
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

# --- 3. Installazione WordPress ---
if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "⚡ New installation detected..."
    
    rm -rf /var/www/html/*
    curl -o wordpress.tar.gz -fL "https://wordpress.org/latest.tar.gz"
    tar -xzf wordpress.tar.gz -C /var/www/html --strip-components=1
    rm wordpress.tar.gz
    
    # Invece di modificare wp-config-sample, creiamo un wp-config.php 
    # che legge le password DIRETTAMENTE dall'ambiente del sistema.
    # Questo è il modo più sicuro in Docker.
    
    cat <<'EOF' > wp-config.php
<?php
define( 'DB_NAME',     getenv('DB_NAME') );
define( 'DB_USER',     getenv('DB_USER') );
define( 'DB_PASSWORD', getenv('DB_PASS') );
define( 'DB_HOST',     getenv('DB_HOST') );
define( 'DB_CHARSET',  'utf8' );
define( 'DB_COLLATE',  '' );

/* --- DOCKER STACK CONFIG --- */
define('FS_METHOD', 'direct');
define('WP_REDIS_HOST', getenv('REDIS_HOST'));
define('WP_REDIS_PORT', 6379);
define('WP_CACHE', true);
define('DISABLE_WP_CRON', true);

/* --- FIX SSL & URL --- */
define('WP_HOME', 'https://' . getenv('DOMAIN'));
define('WP_SITEURL', 'https://' . getenv('DOMAIN'));

if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}

$table_prefix = 'wp_';
define( 'WP_DEBUG', false );

if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
EOF

    # Aggiungi le chiavi di salatura (Salt Keys) via WP-CLI per sicurezza
    wp config shuffle-salts --allow-root

    chown www-data:www-data wp-config.php
    echo "✅ WordPress config generated securely."
fi

echo "🚀 Starting PHP-FPM..."
exec "$@"
