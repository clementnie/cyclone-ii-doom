.PHONY: verify test firmware bitstream
verify:
	python3 phase9/tools/check_release.py
	python3 tools/verify_publication.py
test:
	sh tools/test-phase9.sh
firmware:
	python3 phase9/build.py
bitstream:
	sh phase9/quartus/build.sh
