#!/bin/sh

php-fpm &
httpd -D FOREGROUND
