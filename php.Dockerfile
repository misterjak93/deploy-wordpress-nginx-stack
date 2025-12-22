ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm-alpine

# Argomento per moduli extra definiti nel .env
ARG PHP_EXTRA_EXTENSIONS=""

# --- 1. Dipendenze Base + MSMTP (Mail) + Less ---
RUN apk add --no-cache \
    freetype-dev libjpeg-turbo-dev libpng-dev libzip-dev \
    imagemagick-dev imagemagick icu-dev linux-headers oniguruma-dev \
    libxml2-dev msmtp less \
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

# --- 4. Configurazione Mailpit ---
RUN echo "account default" > /etc/msmtprc \
    && echo "host mailpit" >> /etc/msmtprc \
    && echo "port 1025" >> /etc/msmtprc \
    && echo "auto_from on" >> /etc/msmtprc

WORKDIR /var/www/html

# --- 5. Setup Entrypoint ---
COPY ./php/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN mkdir -p /usr/local/etc/php/conf.d && \
    chown -R www-data:www-data /usr/local/etc/php/conf.d

USER www-data
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
