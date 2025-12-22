#!/bin/sh
set -e

# --- 1. Assicuriamo i permessi corretti ---
# Anche su volumi nuovi, Docker potrebbe montare la cartella come root.
# Forziamo la proprietà a www-data prima di partire.
chown -R www-data:www-data /var/www/html

# Se esiste la cache nginx montata, diamo i permessi anche a quella
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

# --- 3. Installazione WordPress (Solo se manca) ---
if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "⚡ New installation detected. Installing WordPress..."
    
    # Pulizia preventiva
    rm -rf /var/www/html/*
    
    # Download e Estrazione
    curl -o wordpress.tar.gz -fL "https://wordpress.org/latest.tar.gz"
    tar -xzf wordpress.tar.gz -C /var/www/html --strip-components=1
    rm wordpress.tar.gz
    
    cp wp-config-sample.php wp-config.php
    
    # Configurazione Database
    sed -i "s/database_name_here/$DB_NAME/" wp-config.php
    sed -i "s/username_here/$DB_USER/" wp-config.php
    sed -i "s/password_here/$DB_PASS/" wp-config.php
    sed -i "s/localhost/$DB_HOST/" wp-config.php

    # Configurazione Extra (Redis + SSL + Cron Off)
    cat <<EOF >> wp-config.php

/* --- STACK CONFIG --- */
define('FS_METHOD', 'direct');
define('WP_REDIS_HOST', '${REDIS_HOST}');
define('WP_REDIS_PORT', ${REDIS_PORT});
define('WP_CACHE', true);
define('DISABLE_WP_CRON', true);

/* SSL Fix Traefik */
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    \$_SERVER['HTTPS'] = 'on';
}
EOF
    # Fissiamo i permessi sui file appena scaricati
    chown -R www-data:www-data /var/www/html
    echo "✅ WordPress Installed Successfully."
fi

echo "🚀 Starting PHP-FPM..."
# Esegue il comando CMD (php-fpm)
exec "$@"
