.PHONY: check checksums

check:
	@echo "Syntax checking..."
	@bash -n menu.sh
	@for f in modules/*.sh; do bash -n "$$f"; done
	@for f in modules/standalone/*.sh; do bash -n "$$f"; done
	@echo "All files OK"

checksums:
	@cd modules && rm -f modules.sha256 && \
	for f in $$(find . -name '*.sh' -o -name '*.list' | sed 's|^\./||' | sort); do \
		h=$$(git show "HEAD:modules/$$f" | sha256sum | cut -d' ' -f1); \
		printf '%s *%s\n' "$$h" "$$f" >> modules.sha256; \
	done
	@echo "Generated modules/modules.sha256 (from committed LF content)"
	@echo "Note: commit your changes first, then run this to checksum the committed versions"
