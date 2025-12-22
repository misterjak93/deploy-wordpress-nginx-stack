ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm-alpine

# --- 1. Installa Dipendenze di Sistema ed Estensioni PHP ---
RUN apk add --no-cache \
    freetype-dev libjpeg-turbo-dev libpng-dev libzip-dev \
    imagemagick-dev imagemagick icu-dev linux-headers oniguruma-dev \
    # Less è utile per l'output paginato di WP-CLI
    less \ 
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd zip mysqli pdo pdo_mysql opcache intl mbstring exif

# --- 2. Installa Estensioni PECL (Redis e Imagick) ---
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis imagick \
    && docker-php-ext-enable redis imagick \
    && apk del .build-deps

# --- 3. Installa WP-CLI (NUOVO) ---
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# --- Configurazione Finale ---
WORKDIR /var/www/html
COPY ./php/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER www-data
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
