#!/usr/bin/env bash

set -e

# set the default command to exec.  $@ is everything on the command line after the name of the
# image.
set -- bundle exec puma -C ./config/puma.rb "$@"

for arg; do
  case "$arg" in
    -'?'|--help|-h)
      echo ""
      echo "Example run command for this image:"
      echo "docker run --detach --publish 9080:9080 --net=host --dns=10.110.3.220 \\"
      echo "-v \$SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent -v \$HOME/phony-home:/home/appuser:ro \\"
      echo "-e LDAP_BIND_PASSWORD_FILE='/home/appuser/ldap_pw' <image-name:tag>"
      echo ""
      echo "--publish 9080:9080 format: HOST_PORT:CONTAINER_PORT maps request from host to container port."
      echo "--net=host Needed if you're not in the office and on the VPN"
      echo "--dns=10.110.3.220 Needed if you're not in the office and on the VPN; get value from nslookup"
      echo ""
      echo "Environment variables you can set:"
      echo "LDAP_BIND_PASSWORD The password to interact with LDAP AUTH module"
      echo "LDAP_BIND_PASSWORD_FILE file containing the password."
      echo "DATABASE_USER The samson database user, default is root if not set.  Must be set if RAILS_ENV is production."
      echo "DATABASE_USER_FILE file containing username."
      echo "DATABASE_PASSWORD The Samson db password, default is password if not set.  Must be set if RAILS_ENV is production."
      echo "DATABASE_PASSWORD_FILE file containing the password."
      echo "RUN_BIN_SETUP Only accepts value 'true'.  If set, will destroy the database and seed it with initial values."
      echo ""
      exit 0
    ;;
  esac
done


if [ -z "${SSH_AUTH_SOCK}" ]; then
  echo ""
  echo "You need to supply authentication credentials since we have private repositories."
  echo "Add these args to docker run: "
  echo "-v \$SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent -v \$HOME/phony-home:/home/appuser:ro \\"
  echo ""
  echo "The contents of \$HOME/phony-home should include a .ssh folder with permissions 0700."
  echo "Copy your ssh keys int the .ssh folder renamed to their standard names (id_rsa/id_rsa.pub)"
  echo "Create an ssh config file: \$/HOME/phony-home/.ssh/config with only the follow contents:"
  echo "----------->8-----------------"
  echo "StrictHostKeyChecking no"
  echo "ForwardAgent yes"
  echo " "
  echo "Host git.plansource.com"
  echo "   User git"
  echo "   HostName git.plansource.com"
  echo "   IdentityFile /home/appuser/.ssh/id_rsa"
  echo "----------->8-----------------"
fi

# Stolen from the mysql docker-entrypoint script
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
# https://docs.docker.com/engine/swarm/secrets/
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

file_env 'LDAP_BIND_PASSWORD'
if [ -z "${LDAP_BIND_PASSWORD}"]; then
  echo >&2 'error: no LDAP_BIND_PASSWORD was specified.'
  echo >&2 'Set LDAP_BIND_PASSWORD_FILE to the file that contains the password.'
  exit 1
fi

file_env 'DATABASE_USER' 'root'
if [ -z "${DATABASE_USER}" -a "${RAILS_ENV}" == "production"]; then
  echo >&2 'error: no DATABASE_USER was specified.'
  echo >&2 'Set DATABASE_USER_FILE to the file that contains the username.'
  exit 1
fi

file_env 'DATABASE_PASSWORD' 'password'
if [ -z "${DATABASE_PASSWORD}" -a "${RAILS_ENV}" == "production"]; then
  echo >&2 'error: no DATABASE_PASSWORD was specified.'
  echo >&2 'Set DATABASE_PASSWORD_FILE to the file that contains the password.'
  exit 1
fi

if [ "${RUN_BIN_SETUP}" == "true" ]; then
  # Disable environment check is needed if RAILS_ENV is set to production
  # Warning: This destroys all your data if this is set and RAILS_ENV is set production. This probably
  #          only makes sense the first time, or in severe disaster recovery where you need to get
  #          back up quickly... or development environments where we chose the red pill.
  # ENV DISABLE_DATABASE_ENVIRONMENT_CHECK 1
  bin/setup
fi

echo "exec $@"
exec "$@"
