TEST_FILES := $(wildcard test/*.bats)
TEST_TARGETS := $(TEST_FILES:.bats=.bats.run)

.PHONY: test $(TEST_TARGETS)

test: $(TEST_TARGETS)

$(TEST_TARGETS): %.bats.run: %.bats
	@bats $<
