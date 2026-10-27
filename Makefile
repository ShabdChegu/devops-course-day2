# DevOps course command surface.
# ch.0: check + help. Later chapters grow this file:
#   ch.1 run/test/lint | ch.4 build | ch.5 up/down | ch.7 pipeline | ch.8 deploy | ch.15 polish

.DEFAULT_GOAL := help

help:
	@echo "DevOps course - available commands"
	@echo ""
	@echo "  make check   verify prerequisites (tools, docker daemon, free ports)"
	@echo "  make help    this list"

# Prerequisites gate - see scripts/check.sh
check:
	@bash scripts/check.sh

.PHONY: help check
