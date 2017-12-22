# Run this command to test seeding and problems:
#
# docker run --detach --publish 9080:9080 --net=host --dns=10.110.3.220 -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent -v $HOME/tmp/phony-home:/home/appuser:ro -u 1000:1000 samson:ps-1.0.0 
#
# What args mean:
# --detach: daemonize
# --publish: map host port 9080 to container port 9080
# --net: use the hosts network interface
# --dns: This was only necessary if you're not in the office and on the VPN.  Value retrieved via nslookup.
# -v $SSH_AUTH_SOCK...  Bind mount so your ssh-agent works with git-ssh. https://gist.github.com/d11wtq/8699521

# These arguments can be passed into the build as --build-arg UID=XXX --build-arg GID=YYY
ARG UID=1000
ARG GID=1000
ARG RAILS_ENV=development

FROM ruby:2.4.1-slim
ARG UID
ARG GID
ARG RAILS_ENV

RUN apt-get update && apt-get install -y build-essential libmysqlclient-dev libpq-dev libsqlite3-dev wget apt-transport-https git curl \
  && rm -rf /var/lib/apt/lists/*
RUN curl -sL https://deb.nodesource.com/setup_6.x | bash - && apt-get install nodejs

WORKDIR /app

# Mostly static
COPY config.ru /app/
COPY Rakefile /app/
COPY bin /app/bin
COPY public /app/public
COPY db /app/db
COPY .ruby-version /app/.ruby-version

# NPM
COPY package.json /app/package.json
RUN npm install

# Gems
COPY Gemfile /app/
COPY Gemfile.lock /app/
COPY vendor/cache /app/vendor/cache
COPY plugins /app/plugins

# RUN bundle install --quiet --local --jobs 4 || bundle check
RUN bundle install --with mysql2 --local --jobs 4 || bundle check

# Code
COPY config /app/config
COPY app /app/app
COPY lib /app/lib

# Assets
COPY vendor/assets /app/vendor/assets
RUN echo "takes 5 minute" && RAILS_ENV=production PRECOMPILE=1 bundle exec rake assets:precompile

# app, mysql, ldap, ldap, ssh
EXPOSE 9080 3306 389 22

# Use custom seed functionality. https://github.com/zendesk/samson/pull/2440
# COPY custom /app/custom/
COPY custom/seeds.rb custom/seeds.rb
COPY custom/seeds.yml custom/seeds.yml
COPY custom/database.yml config/database.yml
COPY custom/.env.bootstrap .env
COPY custom/entrypoint.sh /docker-entrypoint.sh

# Note: appuser in the container will have access to anything the user with uid:gid has on the host.
RUN groupadd -g ${GID} appuser && useradd -r -u ${UID} -g ${GID} appuser \
  && mkdir -p /home/appuser && chmod 0700 /home/appuser \
  && chown -R appuser:appuser /app

ENV RAILS_ENV=${RAILS_ENV}

USER ${UID}:${GID}
ENTRYPOINT ["/docker-entrypoint.sh"]
