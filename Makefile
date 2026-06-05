.PHONY: check

check:
	@echo "Syntax checking..."
	@bash -n menu.sh
	@for f in modules/*.sh; do bash -n "$$f"; done
	@for f in modules/standalone/*.sh; do bash -n "$$f"; done
	@echo "All files OK"
