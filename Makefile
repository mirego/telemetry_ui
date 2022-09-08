# Build configuration
# -------------------

APP_NAME ?= `grep -Eo 'app: :\w*' mix.exs | cut -d ':' -f 3`
APP_VERSION = `grep -Eo 'version: "[0-9\.]*(-?[a-z]+[0-9]*)?"' mix.exs | cut -d '"' -f 2`

# Linter and formatter configuration
# ----------------------------------

PRETTIER_FILES_PATTERN = '{js,css}/**/*.{ts,js,css}' '../*.md' '../lib/telemetry_ui/web/component/*/*.{ts,js,css}'

# Introspection targets
# ---------------------

.PHONY: help
help: header targets

.PHONY: header
header:
	@echo "\033[34mEnvironment\033[0m"
	@echo "\033[34m---------------------------------------------------------------\033[0m"
	@printf "\033[33m%-23s\033[0m" "APP_NAME"
	@printf "\033[35m%s\033[0m" $(APP_NAME)
	@echo ""
	@printf "\033[33m%-23s\033[0m" "APP_VERSION"
	@printf "\033[35m%s\033[0m" $(APP_VERSION)
	@echo "\n"

.PHONY: targets
targets:
	@echo "\033[34mTargets\033[0m"
	@echo "\033[34m---------------------------------------------------------------\033[0m"
	@perl -nle'print $& if m{^[a-zA-Z_-\d]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'



# Build targets
# -------------

.PHONY: prepare
prepare:
	mix deps.get
	npm ci --prefix assets

# Development targets
# -------------------

.PHONY: dev
dev: ## Run the dev server to test the lib
	elixir dev/server.exs --no-halt

.PHONY: dependencies
dependencies: ## Install dependencies
	mix deps.get
	npm install --prefix assets

# Check, lint and format targets
# ------------------------------

.PHONY: check-code-coverage
check-code-coverage:
	mix coveralls

.PHONY: check-code-security
check-code-security:
	mix sobelow --config

.PHONY: check-format
check-format:
	mix format --dry-run --check-formatted
	cd assets && npx prettier --check $(PRETTIER_FILES_PATTERN)

.PHONY: check-unused-dependencies
check-unused-dependencies:
	mix deps.unlock --check-unused

.PHONY: format
format: ## Format project files
	mix format
	cd assets && npx prettier --write $(PRETTIER_FILES_PATTERN)

.PHONY: lint
lint: lint-elixir lint-scripts ## Lint project files

.PHONY: lint-elixir
lint-elixir:
	mix compile --warnings-as-errors --force
	mix credo --strict

.PHONY: lint-scripts
lint-scripts:
	cd assets && npx eslint .
