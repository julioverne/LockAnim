include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LockAnimSettings
LockAnimSettings_FILES = /mnt/d/codes/lockanim/lockanimsettings/LockAnimSettingsController.mm
LockAnimSettings_INSTALL_PATH = /Library/PreferenceBundles
LockAnimSettings_FRAMEWORKS = UIKit QuartzCore CoreGraphics MessageUI Social Twitter
LockAnimSettings_PRIVATE_FRAMEWORKS = Preferences
LockAnimSettings_CFLAGS = -fobjc-arc
LockAnimSettings_LDFLAGS = -Wl,-segalign,4000
LockAnimSettings_ARCHS = armv7 arm64
export ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/bundle.mk
