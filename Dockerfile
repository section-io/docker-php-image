# Build the build image to build the application
FROM php:7.4-fpm-bullseye

RUN echo 'sendmail_path = "/usr/sbin/ssmtp -t -i"' > /usr/local/etc/php/conf.d/mail.ini
ADD requireme.php .
ADD test.php .

#RUN apt-get update && apt-get install -y ssmtp bash vim git curl patch gzip

RUN set -ex && ( \
  apt-get update \
  && apt-get install -y bash vim \
    ssmtp \
    bash \
    vim \
    libgmp-dev \
    git \
    curl \
    patch \
    gzip \
    # shadow \
    # icu \
    # icu-dev \
    # libcurl \
    libxml2 \
    # libltdl \
    # libzip \
    # libpng \
    # libjpeg-turbo \
    libpng-dev \
    libzip-dev \
    # libjpeg-turbo-dev \
    libxml2-dev \
    libxslt-dev \
    libsodium-dev \
    # zlib-dev \
    autoconf \
    # build-base \
    libfreetype6 \
    libfreetype6-dev \
)

# Install php extensions
# OpenSSL is contained in the base image for php.
RUN set -ex && ( \
  docker-php-ext-install \
    sockets \
    dom \
    gmp \
    pcntl \
    sockets \
    json \
    bcmath \
    opcache \
    sodium \
    soap \
    exif \
    xml \
)

# Install xml libs
RUN set -ex && ( \
  export CFLAGS="-I/usr/src/php" \
  && docker-php-ext-configure \
    xmlreader \
  && docker-php-ext-install \
    xsl \
)


# break it up a bit so build takes less time maybe
RUN set -ex && ( \
  docker-php-ext-configure \
    intl \
  && docker-php-ext-install \
    intl \
    zip \
  #&& docker-php-ext-configure \
  #  gd \
  #  --with-freetype \
  #  --with-jpeg \
  && docker-php-ext-install \
    gd \
    pdo_mysql \
    mysqli \
)

ADD https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz /tmp/
RUN set -ex && ( \
  tar xvfC /tmp/ioncube_loaders_lin_x86-64.tar.gz /tmp/ \
  && rm /tmp/ioncube_loaders_lin_x86-64.tar.gz \
  && mv /tmp/ioncube/ioncube_loader_lin_7.4.so /usr/local/lib/php/extensions/no-debug-non-zts-20190902 \
  && rm -rf /tmp/ioncube \
)

RUN echo 'zend_extension = "/usr/local/lib/php/extensions/no-debug-non-zts-20190902/ioncube_loader_lin_7.4.so"' | tee $PHP_INI_DIR/conf.d/00-ioncube.ini

# install newrelic agent
RUN set -ex && ( \
  curl -L https://download.newrelic.com/php_agent/archive/9.9.0.260/newrelic-php5-9.9.0.260-linux-musl.tar.gz | tar -C /tmp -zx \
  && export NR_INSTALL_USE_CP_NOT_LN=1 \
  && export NR_INSTALL_PATH=/usr/local/bin/php \
  && /tmp/newrelic-php5-*/newrelic-install install 2>&1 | tee -a /tmp/newrelic-install.log \
  && rm -rf /tmp/newrelic-php5-* /tmp/nrinstall* \
  && mkdir -p /var/log/newrelic \
  && touch /var/log/newrelic/newrelic-daemon.log \
  && touch /var/log/newrelic/php_agent.log \
#  && chown xfs:xfs /var/log/newrelic/* \
)

# cleanup
RUN set -ex && ( \
  apt-get remove -y \
    libzip-dev \
    #zlib-dev \
    libfreetype6-dev \
    libpng-dev \
    # libjpeg-turbo-dev \
    libxml2-dev \
)


# install composer 1, since 2 is not yet supported
RUN set -ex && ( \
  curl -s https://getcomposer.org/installer | php -- --1 \
  && mv composer.phar /usr/local/bin/composer1 \
)

# install composer 2 to /usr/local/bin/composer2
RUN set -ex && ( \
  curl -s https://getcomposer.org/installer | php \
  && mv composer.phar /usr/local/bin/composer2 \
)

RUN ln -sf /usr/local/bin/composer1 /usr/local/bin/composer

# Default php ini and pool conf values. Can be overridden in the customers build process if desired
RUN echo -e "[php]\n" \
          "max_execution_time     = 900\n" \
          "short_open_tag         = Off\n" \
          "log_errors             = On\n" \
          "error_log              = /dev/stderr\n" \
          "memory_limit           = 2G\n" \
          "error_reporting        = E_ALL\n" \
          "display_errors         = Off\n" \
          "ignore_repeated_errors = Off\n" \
          "ignore_repeated_source = Off\n" \
          "report_memleaks        = On\n" \
          "upload_max_filesize = 240M\n" \
          "post_max_size = 240M\n" \
          "client_max_body_size = 200M\n" \
          "max_input_vars = 5000\n"
          #"sendmail_path = \"/usr/sbin/ssmtp -t -i\"\n" > $PHP_INI_DIR/conf.d/99-webscale.ini

RUN set -ex && ( cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" )

RUN echo -e "[www]\n" \
          "user = xfs\n" \
          "group = xfs\n" \
          "listen = 127.0.0.1:9000\n" \
          "pm = dynamic\n" \
          "pm.max_children = 60\n" \
          "pm.start_servers = 5\n" \
          "pm.min_spare_servers = 5\n" \
          "pm.max_spare_servers = 30\n" \
          "pm.max_requests = 1000\n"
          #"access.format = \"%R - %u %t \\"%m %r%Q%q\\" %s %f %{mili}d %{kilo}M %C%%\"\n" > /usr/local/etc/php-fpm.d/www.conf
