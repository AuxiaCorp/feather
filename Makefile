.PHONY: all build test install
all: build
build:
	./scripts/build.sh
test:
	./scripts/test.sh
install:
	./scripts/install-linux.sh
