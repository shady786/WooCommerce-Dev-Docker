#!/bin/bash
set -e

# env variables
PROJECT_NAME=${PROJECT_NAME}
WP_VERSION=${WP_VERSION}
WP_MULTISITE=${WP_MULTISITE}
WC_VERSION=${WC_VERSION}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
DB_HOST=${DB_HOST}
DB_NAME=${DB_NAME}
DB_PASSWORD=${DB_PASSWORD}
WP_USER=${WP_USER}
WP_EMAIL=${WP_EMAIL}
WP_PASSWORD=${WP_PASSWORD}
WP_TITLE=${WP_TITLE}

# install wordpress
if ! [ -e index.php -a -e wp-includes/version.php ]; then
  wp core download --allow-root --version=$WP_VERSION
fi

# wp-config
if [ ! -e wp-config.php ]; then
  wp core config --allow-root --skip-check --dbname=$DB_NAME --dbuser=root --dbpass=$DB_PASSWORD --dbhost=$DB_HOST --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'SCRIPT_DEBUG', true );
define( 'WP_HOME', 'http://php'. PHP_MAJOR_VERSION . PHP_MINOR_VERSION .'.local' );
define( 'WP_SITEURL', 'http://php'. PHP_MAJOR_VERSION . PHP_MINOR_VERSION .'.local' );
PHP
fi

# set up db & plugins
if ! $(wp core is-installed --allow-root); then

  # install WordPress
  if [[ $WP_MULTISITE == "1" ]]; then
    wp core multisite-install --allow-root --url=localhost --title=$WP_TITLE --admin_user=$WP_USER --admin_password=$WP_PASSWORD --admin_email=$WP_EMAIL
  else
    wp core install --allow-root --url=localhost --title=$WP_TITLE --admin_user=$WP_USER --admin_password=$WP_PASSWORD --admin_email=$WP_EMAIL
  fi

  # install WooCommerce: url, version, latest
  if [[ $WC_VERSION == http* ]]; then
    wp plugin install $WC_VERSION --allow-root --activate
  elif [[ $WC_VERSION == "latest" ]]; then
    wp plugin install woocommerce --allow-root --activate
  else
    wp plugin install woocommerce --allow-root --version=$WC_VERSION --activate
  fi

  # wordpress and woocommerce settings
  wp option update woocommerce_api_enabled yes --allow-root
  wp option update woocommerce_calc_taxes yes --allow-root
  wp rewrite structure '/%year%/%monthnum%/%postname%' --allow-root

  # activate the current project
  wp plugin activate $PROJECT_NAME --allow-root

  # install fake data
  php -d memory_limit=512M "$(which wp)" package install git@github.com:kilbot/wp-cli-fixtures.git --allow-root
#  wp fixtures load --allow-root


#  wp rewrite flush --hard --allow-root
fi

# install unit test library
if [ ! -d wordpress-tests-lib ]; then
  mkdir wordpress-tests-lib
  svn co --quiet https://develop.svn.wordpress.org/tags/$(wp core version --allow-root)/tests/phpunit/includes/ wordpress-tests-lib/includes
  curl -o wordpress-tests-lib/wp-tests-config-sample.php https://develop.svn.wordpress.org/tags/$(wp core version --allow-root)/wp-tests-config-sample.php
fi

# unit tests config
if [ ! -f wordpress-tests-lib/wp-tests-config.php ]; then
  cp wordpress-tests-lib/wp-tests-config-sample.php wordpress-tests-lib/wp-tests-config.php
  sed -i "s:dirname( __FILE__ ) . '/src/':'$(pwd)/':" wordpress-tests-lib/wp-tests-config.php
  sed -i "s/youremptytestdbnamehere/$DB_NAME/" wordpress-tests-lib/wp-tests-config.php
  sed -i "s/yourusernamehere/$DB_USER/" wordpress-tests-lib/wp-tests-config.php
  sed -i "s/yourpasswordhere/$DB_PASSWORD/" wordpress-tests-lib/wp-tests-config.php
  sed -i "s|localhost|${DB_HOST}|" wordpress-tests-lib/wp-tests-config.php
fi
