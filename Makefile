# Maintenance tasks for this chezmoi source directory.
#
# This file is for working ON the repo, so .chezmoiignore keeps it out of $HOME.
# Brewfile itself is different: chezmoi manages ~/Brewfile, which is why brew-dump rewrites it in place here and lets `chezmoi apply` carry it over.

BREWFILE := Brewfile

# `brew bundle dump` also emits uv/npm entries for language packages installed outside Homebrew.
BREWFILE_DROP := ^(uv|npm) "

.DEFAULT_GOAL := help

.PHONY: help brew-dump brew-check brew-install brew-upgrade brew-doctor

help: ## Show this help
	@grep -hE '^[a-z][a-z-]*:.*## ' $(MAKEFILE_LIST) \
		| sed -e 's/:.*## /|/' \
		| awk -F'|' '{ printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }'

brew-dump: brew-doctor ## Regenerate Brewfile from what is currently installed
	brew bundle dump --file=$(BREWFILE) --no-describe --force
	@grep -Ev '$(BREWFILE_DROP)' $(BREWFILE) > $(BREWFILE).tmp && mv $(BREWFILE).tmp $(BREWFILE)
	@echo
	@git --no-pager diff --stat -- $(BREWFILE)

brew-check: ## Verify every declared package is installed and current
	brew bundle check --file=$(BREWFILE) --verbose

brew-install: ## Install declared packages that are missing (what bootstrap runs)
	brew bundle install --file=$(BREWFILE) --no-upgrade

brew-upgrade: ## Install missing packages and upgrade outdated ones
	brew bundle install --file=$(BREWFILE)

brew-doctor: ## Warn about untrusted taps, whose formulae dump silently skips
	@untrusted=$$(brew tap-info --json --installed \
		| python3 -c 'import json,sys; print(" ".join(t["name"] for t in json.load(sys.stdin) if not t.get("trusted")))'); \
	if [ -n "$$untrusted" ]; then \
		echo "⚠️  untrusted taps: $$untrusted"; \
		echo "   brew bundle dump OMITS their formulae — run: brew trust <tap>"; \
	else \
		echo "✓ all taps trusted"; \
	fi
