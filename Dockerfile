# syntax=docker/dockerfile:1
ARG RUBY_IMAGE=ruby:3.2.7-slim-bookworm

# Build stage: compile native gems (json, etc.) with the toolchain
FROM ${RUBY_IMAGE} AS build

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*

RUN gem install bundler -v 2.6.6 --no-document

WORKDIR /action
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without development \
 && bundle config set --local deployment true \
 && bundle config set --local path /action/vendor/bundle \
 && bundle install --jobs 4

# Runtime stage: no compiler, only Ruby + installed gems
FROM ${RUBY_IMAGE}

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && gem install bundler -v 2.6.6 --no-document

ENV BUNDLE_GEMFILE=/action/Gemfile \
    BUNDLE_PATH=/action/vendor/bundle \
    BUNDLE_WITHOUT=development \
    BUNDLE_DEPLOYMENT=true

WORKDIR /action
COPY --from=build /action/vendor /action/vendor
COPY Gemfile Gemfile.lock ./
COPY app app
COPY entrypoint.rb docker-entrypoint.sh ./

# GitHub overrides WORKDIR with /github/workspace, so use absolute paths
ENTRYPOINT ["/action/docker-entrypoint.sh"]
