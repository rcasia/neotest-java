.PHONY: clean

mvn = ./tests/fixtures/maven-demo/mvnw
gradle_groovy = ./tests/fixtures/gradle-groovy-demo/gradlew
gradle_kotlin = ./tests/fixtures/gradle-kotlin-demo/gradlew

all: hooks test

hooks:
	cp -f ./git-hooks/* .git/hooks/

test: install
	bash scripts/test

test-fail-fast: install
	bash scripts/test --fail-fast

prepare-demo:
	# it is expected to fail because there are failing tests
	-$(mvn) -f tests/fixtures/maven-demo/pom.xml clean verify --fail-at-end -Dtest="*"
	-$(gradle_groovy) -p tests/fixtures/gradle-groovy-demo clean test --continue
	-$(gradle_kotlin) -p tests/fixtures/gradle-kotlin-demo clean test --continue

install: deps/plenary.nvim deps/neotest deps/nvim-nio install-parsers

deps/plenary.nvim:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git $@


deps/neotest:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-neotest/neotest $@

deps/nvim-nio:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-neotest/nvim-nio $@

install-parsers:
	# nvim --headless -u tests/testrc.vim -c "TSInstall java" +q
	nvim --headless -u tests/testrc.vim -c "lua require('nvim-treesitter.install').install('java'):wait(300000)" +q


clean:
	rm -rf deps/plenary.nvim deps/neotest
	$(mvn) -f tests/fixtures/maven-demo/pom.xml clean
	$(gradle_groovy) -p tests/fixtures/gradle-groovy-demo clean
	$(gradle_kotlin) -p tests/fixtures/gradle-kotlin-demo clean

validate:
	stylua --check .

format:
	stylua .
