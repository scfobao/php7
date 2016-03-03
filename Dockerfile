FROM ubuntu:trusty

ENV DEBIAN_FRONTEND noninteractive

# persistent / runtime deps
RUN apt-get update && apt-get install -y sudo ca-certificates curl librecode0 libsqlite3-0 libxml2 --no-install-recommends && rm -r /var/lib/apt/lists/*

# phpize deps
RUN apt-get update && apt-get install -y autoconf file g++ gcc libc-dev make pkg-config re2c --no-install-recommends && rm -r /var/lib/apt/lists/*

ENV PHP_INI_DIR /usr/local/etc/php
RUN mkdir -p $PHP_INI_DIR/conf.d

ENV GPG_KEYS 1A4E8B7277C42E53DBA9C7B9BCAA30EA9C0D5763
RUN set -xe \
    && for key in $GPG_KEYS; do \
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
    done

ENV PHP_VERSION 7.0.3
ENV PHP_FILENAME php-7.0.3.tar.xz
ENV PHP_SHA256 3af2b62617a0e46214500fc3e7f4a421067224913070844d3665d6cc925a1cca

# --enable-mysqlnd is included below because it's harder to compile after the fact the extensions are (since it's a plugin for several extensions, not an extension in itself)
RUN buildDeps=" \
        $PHP_EXTRA_BUILD_DEPS \
        libcurl4-openssl-dev \
        libreadline6-dev \
        librecode-dev \
        libsqlite3-dev \
        libssl-dev \
        libxml2-dev \
        xz-utils \
        libpng-dev \
        libicu-dev \
        libxslt-dev \
    " \
    && set -x \
    && apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
    && curl -fSL "http://php.net/get/$PHP_FILENAME/from/this/mirror" -o "$PHP_FILENAME" \
    && echo "$PHP_SHA256 *$PHP_FILENAME" | sha256sum -c - \
    && curl -fSL "http://php.net/get/$PHP_FILENAME.asc/from/this/mirror" -o "$PHP_FILENAME.asc" \
    && gpg --verify "$PHP_FILENAME.asc" \
    && mkdir -p /usr/src/php \
    && tar -xf "$PHP_FILENAME" -C /usr/src/php --strip-components=1 \
    && rm "$PHP_FILENAME"* \
    && cd /usr/src/php \
    && ./configure \
        --with-config-file-path="$PHP_INI_DIR" \
        --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
        $PHP_EXTRA_CONFIGURE_ARGS \
        --disable-cgi \
        --enable-mysqlnd \
        --enable-zip \
        --enable-intl \
        --enable-mbstring \
        --enable-mongo \
        --enable-fpm \
        --with-curl \
        --with-openssl \
        --with-readline \
        --with-recode \
        --with-zlib \
        --with-gd \
        --with-xsl=/usr \
        --with-gettext=/usr/local/opt/gettext \
    && make -j"$(nproc)" \
    && make install \
    && { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $buildDeps \
    && make clean

COPY docker-php-ext-* /usr/local/bin/

ENV DEBIAN_FRONTEND newt
