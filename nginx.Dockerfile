FROM nginx:alpine

# Installa le dipendenze per la compilazione
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    libc-dev \
    make \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    linux-headers \
    curl \
    gnupg \
    libxslt-dev \
    gd-dev \
    geoip-dev

# Scarica i sorgenti di Nginx corrispondenti alla versione installata
RUN curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
    && mkdir -p /usr/src \
    && tar -zxC /usr/src -f nginx.tar.gz \
    && rm nginx.tar.gz

# Scarica il modulo ngx_cache_purge (usa il fork compatibile con Nginx 1.8+)
RUN curl -fSL https://github.com/nginx-modules/ngx_cache_purge/archive/2.5.3.tar.gz -o ngx_cache_purge.tar.gz \
    && mkdir -p /usr/src/ngx_cache_purge \
    && tar -zxC /usr/src/ngx_cache_purge -f ngx_cache_purge.tar.gz --strip-components=1 \
    && rm ngx_cache_purge.tar.gz

# Compila Nginx con il modulo aggiunto
RUN cd /usr/src/nginx-$NGINX_VERSION \
    && ./configure --with-compat --add-dynamic-module=/usr/src/ngx_cache_purge $(nginx -V) \
    && make modules \
    && cp objs/ngx_http_cache_purge_module.so /usr/lib/nginx/modules/

# Aggiunge il caricamento del modulo all'inizio del file di configurazione principale
RUN sed -i '1iload_module /usr/lib/nginx/modules/ngx_http_cache_purge_module.so;' /etc/nginx/nginx.conf

# Rimuove le dipendenze di compilazione per mantenere l'immagine leggera
RUN apk del .build-deps \
    && rm -rf /usr/src/nginx-$NGINX_VERSION /usr/src/ngx_cache_purge
