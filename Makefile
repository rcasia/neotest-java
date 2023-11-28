.PHONY: clean

mvn = ./tests/fixtures/maven-demo/mvnw
gradle_groovy = ./tests/fixtures/gradle-groovy-demo/gradlew
gradle_kotlin = ./tests/fixtures/gradle-kotlin-demo/gradlew

all: prepare-demo test

test: install
	./scripts/test

test-fail-fast: install
	./scripts/test --fail-fast

prepare-demo:
	# it is expected to fail because there are failing tests
	-$(mvn) -f tests/fixtures/maven-demo/pom.xml clean verify --fail-at-end -Dtest="*"
	-$(gradle_groovy) -p tests/fixtures/gradle-groovy-demo clean test --continue
	-$(gradle_kotlin) -p tests/fixtures/gradle-kotlin-demo clean test --continue

install: deps/plenary.nvim deps/nvim-treesitter deps/nvim-treesitter/parser/java.so deps/neotest

deps/plenary.nvim:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git $@

deps/nvim-treesitter:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter.git $@

deps/neotest:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-neotest/neotest $@

deps/nvim-treesitter/parser/java.so: deps/nvim-treesitter
	nvim --headless -u tests/minimal_init.vim -c "TSInstallSync java | quit"

clean:
	rm -rf deps/plenary.nvim deps/nvim-treesitter deps/neotest
	$(mvn) -f tests/fixtures/maven-demo/pom.xml clean
	$(gradle_groovy) -p tests/fixtures/gradle-groovy-demo clean
	$(gradle_kotlin) -p tests/fixtures/gradle-kotlin-demo clean

validate:
	stylua --check .

format:
	stylua .
