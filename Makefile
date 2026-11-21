# Makefile for RamSaltMan
# Developer: Shauryaveer Singh Sapra (@theskulltrapper)

.PHONY: all app dmg clean run

all: app dmg

app:
	@./Scripts/build_app.sh

dmg:
	@./Scripts/create_dmg.sh

run: app
	@open build/RamSaltMan.app

clean:
	@rm -rf build dist /tmp/swift-cache
	@echo "Cleaned build artifacts."
