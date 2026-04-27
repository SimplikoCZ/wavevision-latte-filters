bin=vendor/bin
chrome:=$(shell command -v google-chrome 2>/dev/null)
codeSnifferRuleset=codesniffer-ruleset.xml
coverage=$(temp)/coverage
coverageClover=$(coverage)/coverage.xml
php=php
src=src
temp=temp
tests=tests
dirs:=$(src) $(tests)

docker-bin=docker compose run --rm app
docker-composer=$(docker-bin) composer

all:
	 @$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

# Docker

docker-build:
	docker compose build

docker-up:
	docker compose up -d

docker-down:
	docker compose down

# Setup

composer:
	$(docker-composer) install

update:
	$(docker-composer) update

reset:
	rm -rf $(temp)/cache
	$(docker-composer) dumpautoload

di: reset
	$(docker-bin) bin/extract-services

fix: reset check-syntax phpcbf phpcs phpstan test

# QA

check-syntax:
	$(docker-bin) $(bin)/parallel-lint -e $(php) $(dirs)

phpcs:
	$(docker-bin) $(bin)/phpcs -sp --standard=$(codeSnifferRuleset) --extensions=php $(dirs)

phpcbf:
	$(docker-bin) $(bin)/phpcbf -spn --standard=$(codeSnifferRuleset) --extensions=php $(dirs) ; true

phpstan:
	$(docker-bin) $(bin)/phpstan analyze $(dirs)

# Tests

test:
	$(docker-bin) $(bin)/phpunit

test-coverage: reset
	$(docker-bin) $(bin)/phpunit --coverage-html=$(coverage)

test-coverage-clover: reset
	$(docker-bin) $(bin)/phpunit --coverage-clover=$(coverageClover)

test-coverage-report: test-coverage-clover
	$(docker-bin) $(bin)/php-coveralls --coverage_clover=$(coverageClover) --verbose

test-coverage-open: test-coverage
ifndef chrome
	open -a 'Google Chrome' $(coverage)/index.html
else
	google-chrome $(coverage)/index.html
endif

ci: check-syntax phpcs phpstan test-coverage-report
