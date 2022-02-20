FROM php:fpm-alpine3.15

RUN apk update

RUN apk add --no-cache apache2-proxy php8-fpm

# Enable image manipulation required by concrete, specifically GD with png, jpeg, and gif support
RUN apk add --no-cache \
  freetype-dev \
  libpng-dev \
  jpeg-dev \
  libjpeg-turbo-dev
RUN docker-php-ext-configure gd --enable-gd --with-jpeg
RUN NUMPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
  && docker-php-ext-install -j${NUMPROC} gd

# Add SimpleXml, iconv, FileInfo, mbstring, and curl which are required by concrete
RUN apk add --no-cache php8-simplexml php8-iconv php8-fileinfo php8-mbstring php8-curl
RUN apk add --no-cache php8-mysqli
RUN docker-php-ext-install mysqli pdo pdo_mysql
RUN apk add libzip-dev zlib-dev \
  && docker-php-ext-configure zip \
  && docker-php-ext-install zip

# Download concrete
WORKDIR /var/www/localhost/htdocs
RUN rm index.html
RUN apk add --no-cache unzip 
RUN curl -L https://www.concretecms.org/download_file/3254ddbf-35f0-4c92-8ed1-1fb6b9c0f0d4 > concrete.zip
RUN unzip concrete.zip
RUN apk del unzip 

# Move concrete into place
WORKDIR /var/www/localhost/htdocs/concrete-cms-9.0.2
RUN mv * ..

# Remove archive
WORKDIR /var/www/localhost/htdocs
RUN rm -rf concrete.zip concrete-cms-9.0.2

# Disable safe mode, and set minimum memory, as required by concrete
RUN echo "safe_mode = Off" >> /etc/php8/php.ini
RUN echo "memory_limit = 64M" >> /etc/php8/php.ini

# Enable fpm fastcgi, and use index.php as index file
ADD fpm.conf /etc/apache2/conf.d/

# Set fpm user to apache
WORKDIR /etc/php8/php-fpm.d/
RUN mv www.conf www.orig \
  && sed 's/^user[ \t]*=.*/user = apache/;s/group[ \t]*=.*/group = apache/' www.orig > www.conf \
  && rm www.orig

# Add entrypoint file to start fpm in background and apache in foreground
ADD entrypoint.sh /usr/local/bin/entrypoint.sh 

# Make files and configuration directories writables, as required by concrete
WORKDIR /var/www/localhost/htdocs
RUN chmod ugo+w -R application/config application/files packages

CMD ["entrypoint.sh"]

