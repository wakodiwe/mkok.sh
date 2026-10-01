PREFIX ?= $(HOME)
DEST   := $(PREFIX)/.local/lib/sh/mkok.sh
SRC    := $(PWD)/src/mkok.sh

.PHONY: devinstall install uninstall

install: uninstall
	@mkdir -p $(dir $(DEST))
	@cp -v $(SRC) $(DEST)
	@chmod +x $(DEST)
	@printf "Installed to %s\n" "$(DEST)"

uninstall:
	@rm -f $(DEST)
	@printf "Removed %s\n" "$(DEST)"

devinstall: uninstall
	@mkdir -p $(dir $(DEST))
	@ln -s $(SRC) $(DEST)
	@printf "Linked to %s\n" "$(DEST)"
