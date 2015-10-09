FROM php:5.6-apache

RUN apt-get update && apt-get install -y \
        aria2 \
        curl \
        unzip \
        php5-curl \
	bzip2 \
	libcurl4-openssl-dev \
	libfreetype6-dev \
	libicu-dev \
	libjpeg-dev \
	libmcrypt-dev \
	libmemcached-dev \
	libpng12-dev \
	libpq-dev \
	libxml2-dev \
	&& rm -rf /var/lib/apt/lists/*

#gpg key from https://owncloud.org/owncloud.asc
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys E3036906AD9F30807351FAC32D5D5E97F6978A26

# https://doc.owncloud.org/server/8.1/admin_manual/installation/source_installation.html#prerequisites
RUN docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
	&& docker-php-ext-install gd intl mbstring mcrypt mysql opcache pdo_mysql pdo_pgsql pgsql zip

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# PECL extensions
RUN pecl install APCu-beta redis memcached \
	&& docker-php-ext-enable apcu redis memcached

RUN a2enmod rewrite

ENV OWNCLOUD_VERSION 8.1.3
VOLUME /var/www/html

RUN curl -fsSL -o owncloud.tar.bz2 \
		"https://download.owncloud.org/community/owncloud-${OWNCLOUD_VERSION}.tar.bz2" \
	&& curl -fsSL -o owncloud.tar.bz2.asc \
		"https://download.owncloud.org/community/owncloud-${OWNCLOUD_VERSION}.tar.bz2.asc" \
	&& gpg --verify owncloud.tar.bz2.asc \
	&& tar -xjf owncloud.tar.bz2 -C /usr/src/ \
	&& rm owncloud.tar.bz2 owncloud.tar.bz2.asc

# Rename dirctory to appid & enable ocdownloader by default
RUN curl -fsSL -o oc.zip \
                "https://github.com/DjazzLab/ocdownloader/archive/master.zip" \
        && rm -rf /dev/shm/ocdownloader-master \
        && unzip oc.zip -d /dev/shm \
        && sed -i 's|</id>|</id><default_enable/>|' /dev/shm/ocdownloader-master/appinfo/info.xml \
        && mv /dev/shm/ocdownloader-master /usr/src/owncloud/apps/ocdownloader \
        && rm oc.zip

COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# BAD Hotfix: give www-data permission to login
RUN usermod -s /bin/sh www-data

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
