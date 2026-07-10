.PHONY: test verify install uninstall package

test:
	bash tests/run.sh

verify:
	bash scripts/verify.sh

install:
	./install.sh

uninstall:
	./install.sh --uninstall

package:
	tar --exclude=.git --exclude='__pycache__' -czf ../claude-mode.tar.gz .
