ARG PHP_VERSION=8.3

FROM php:${PHP_VERSION}-fpm-alpine

ARG PHP_EXTRA_EXTENSIONS=""

# --- 1. Dipendenze Base + Less + Shadow ---
RUN apk add --no-cache \
    freetype-dev libjpeg-turbo-dev libpng-dev libzip-dev \
    imagemagick-dev imagemagick icu-dev linux-headers oniguruma-dev \
    libxml2-dev less shadow \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd zip mysqli pdo pdo_mysql opcache intl mbstring exif

# --- 2. Moduli Extra Dinamici ---
RUN if [ ! -z "$PHP_EXTRA_EXTENSIONS" ]; then \
        echo "🔥 Installing extra: $PHP_EXTRA_EXTENSIONS"; \
        docker-php-ext-install -j$(nproc) $PHP_EXTRA_EXTENSIONS; \
    fi

# --- 3. Redis, Imagick & WP-CLI ---
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis imagick \
    && docker-php-ext-enable redis imagick \
    && apk del .build-deps \
    && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# --- 4. FIX RETE FPM (SOLUZIONE NUCLEARE) ---
# Rimuove la configurazione default che ascolta solo su 127.0.0.1
# E crea un file zz-docker.conf che forza l'ascolto sulla porta 9000 esterna
RUN rm -f /usr/local/etc/php-fpm.d/www.conf \
    && rm -f /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo '[global]' > /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'daemonize = no' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'error_log = /proc/self/fd/2' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo '[www]' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'listen = 9000' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'listen.owner = www-data' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'listen.group = www-data' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'pm = dynamic' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'pm.max_children = 50' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'pm.start_servers = 5' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'pm.min_spare_servers = 5' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'pm.max_spare_servers = 35' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'access.log = /proc/self/fd/2' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'clear_env = no' >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo 'catch_workers_output = yes' >> /usr/local/etc/php-fpm.d/zz-docker.conf

# --- 5. Allineamento User ID ---
RUN usermod -u 82 www-data && groupmod -g 82 www-data

WORKDIR /var/www/html

# --- 6. Entrypoint ---
COPY ./php/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN mkdir -p /usr/local/etc/php/conf.d

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
