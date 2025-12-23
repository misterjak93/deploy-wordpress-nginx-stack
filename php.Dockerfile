# 1. Definiamo la versione PRIMA del FROM per usarla nel tag dell'immagine
ARG PHP_VERSION=8.3

FROM php:${PHP_VERSION}-fpm-alpine

# 2. Definiamo gli altri argomenti DOPO il FROM per usarli durante la build
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

# --- 4. Allineamento User ID (Best Practice) ---
# Assicura che l'utente www-data abbia ID 82 (standard Alpine)
RUN usermod -u 82 www-data && groupmod -g 82 www-data

WORKDIR /var/www/html

# --- 5. Configurazione Entrypoint ---
COPY ./php/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN mkdir -p /usr/local/etc/php/conf.d

# NOTA: Rimaniamo root qui. L'entrypoint girerà come root per fare il setup,
# poi lancerà php-fpm che gestirà internamente il cambio utente a www-data.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
