# Makefile for Phoenix-RTOS 3
#
# Copyright 2025 Phoenix Systems
#

PORTS_SUPPORTED_VERSIONS :=
PORTS_SUPPORTED_VERSIONS += openssl=1.1.1a


PORTS_DEFAULT_VERSIONS :=
PORTS_DEFAULT_VERSIONS += openssl=1.1.1a


PORTS_VERSIONS := $(PORTS_DEFAULT_VERSIONS) $(PORTS_DEFAULT_VERSIONS_PROJECT)


PORTS_INVALID_VERSIONS=$(filter-out $(PORTS_SUPPORTED_VERSIONS),$(PORTS_DEFAULT_VERSIONS))

ifneq ($(PORTS_INVALID_VERSIONS), )
 $(error Invalid versions in PORTS_DEFAULT_VERSIONS: $(PORTS_INVALID_VERSIONS))
endif


PORTS_INVALID_VERSIONS_PROJECT=$(filter-out $(PORTS_SUPPORTED_VERSIONS),$(PORTS_DEFAULT_VERSIONS_PROJECT))

ifneq ($(PORTS_INVALID_VERSIONS_PROJECT), )
 $(error Invalid versions in PORTS_DEFAULT_VERSIONS_PROJECT: $(PORTS_INVALID_VERSIONS_PROJECT))
endif


# Obtain unique ports (without versions)
define ports_uniq
$(sort $(foreach PORT_VERSION, $(1),$(word 1,$(subst =, ,$(PORT_VERSION)))))
endef


# Use only the last definition of each port
define ports_last_version
$(foreach PORT\
  ,$(call ports_uniq, $(1))\
  ,$(lastword $(filter $(PORT)=%, $(1))))
endef


define check_default_versions
$(foreach PORT\
	,$(PORTS_VERSIONS)\
	,$(call check_default_version, $(PORT)))
endef


define ports_versions
$(call ports_last_version,$(PORTS_VERSIONS) $(LOCAL_PORTS_VERSIONS))
endef


define port_to_folder
ports/$(subst =,/,$(strip $(1)))
endef


define ports_iflags
$(foreach PORT, $(call ports_versions), -I$(PREFIX_H)$(call port_to_folder,$(PORT)))
endef


define ports_lflags
$(foreach PORT, $(call ports_versions), -L$(PREFIX_A)$(call port_to_folder,$(PORT)))
endef
