.PHONY: check checksums

check:
	@echo "Syntax checking..."
	@bash -n menu.sh
	@for f in modules/*.sh; do bash -n "$$f"; done
	@for f in modules/standalone/*.sh; do bash -n "$$f"; done
	@echo "All files OK"

checksums:
	@echo "GitHub Actions auto-regenerates modules.sha256 on push."
	@echo "Only use this target if you need to generate checksums locally."
	@cd modules && rm -f modules.sha256 && \
	for f in $$(find . -name '*.sh' -o -name '*.list' | sed 's|^\./||' | sort); do \
		h=$$(git show "HEAD:modules/$$f" | sha256sum | cut -d' ' -f1); \
		printf '%s *%s\n' "$$h" "$$f" >> modules.sha256; \
	done
	@echo "Generated modules/modules.sha256"
