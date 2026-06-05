.PHONY: check checksums

check:
	@echo "Syntax checking..."
	@bash -n menu.sh
	@for f in modules/*.sh; do bash -n "$$f"; done
	@for f in modules/standalone/*.sh; do bash -n "$$f"; done
	@echo "All files OK"

checksums:
	@cd modules && find . -name '*.sh' -o -name '*.list' | sed 's|^\./||' | sort | xargs sha256sum > modules.sha256
	@echo "Generated modules/modules.sha256"
