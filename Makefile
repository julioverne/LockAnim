include $(THEOS)/makefiles/common.mk

SUBPROJECTS += lockanimhooks
SUBPROJECTS += lockanimsettings

include $(THEOS_MAKE_PATH)/aggregate.mk

all::
	
