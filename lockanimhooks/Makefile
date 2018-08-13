include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LockAnim

LockAnim_FILES = /mnt/d/codes/lockanim/lockanimhooks/LockAnim.xm
LockAnim_FRAMEWORKS = CydiaSubstrate UIKit CoreGraphics CoreFoundation Foundation QuartzCore
LockAnim_LDFLAGS = -Wl,-segalign,4000

export ARCHS = armv7 arm64
LockAnim_ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/tweak.mk
	
all::
