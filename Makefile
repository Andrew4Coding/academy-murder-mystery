# TestFlight: upload every app to internal testers, wait for App Store Connect
# to process the builds, then submit the same builds to external testers.
#
#   make release                 all three apps in parallel
#   make release-ios             one app (also release-mac, release-adminpad)
#   make beta                    internal only, all apps
#   make external                external only, all apps (builds must be processed)
#   make release DELAY=300       wait 5 minutes between internal and external
#   make release STAGGER=0       start all three at once
#
# Needs fastlane/.env (see scripts/setup-ci.sh) and BETA_REVIEW_* for external.

export LC_ALL ?= en_US.UTF-8
export LANG ?= en_US.UTF-8

FASTLANE := bundle exec fastlane
DELAY ?= 120
STAGGER ?= 20

APPS := ios mac adminpad

.PHONY: release beta external $(addprefix release-,$(APPS)) $(addprefix beta-,$(APPS)) $(addprefix external-,$(APPS))

release:
	@$(MAKE) --no-print-directory -j$(words $(APPS)) $(addprefix release-,$(APPS))

beta:
	@$(MAKE) --no-print-directory -j$(words $(APPS)) $(addprefix beta-,$(APPS))

external:
	@$(MAKE) --no-print-directory -j$(words $(APPS)) $(addprefix external-,$(APPS))

release-ios: ; @sleep $(call stagger,0); $(FASTLANE) ios beta && sleep $(DELAY) && $(FASTLANE) ios beta_external
release-mac: ; @sleep $(call stagger,1); $(FASTLANE) mac beta && sleep $(DELAY) && $(FASTLANE) mac beta_external
release-adminpad: ; @sleep $(call stagger,2); $(FASTLANE) ios adminpad_beta && sleep $(DELAY) && $(FASTLANE) ios adminpad_beta_external

beta-ios: ; @sleep $(call stagger,0); $(FASTLANE) ios beta
beta-mac: ; @sleep $(call stagger,1); $(FASTLANE) mac beta
beta-adminpad: ; @sleep $(call stagger,2); $(FASTLANE) ios adminpad_beta

external-ios: ; @$(FASTLANE) ios beta_external
external-mac: ; @$(FASTLANE) mac beta_external
external-adminpad: ; @$(FASTLANE) ios adminpad_beta_external

stagger = $(shell echo $$(( $(1) * $(STAGGER) )))
