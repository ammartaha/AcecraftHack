TARGET := iphone:clang:14.5:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = ACECRAFT

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AcecraftHack

AcecraftHack_FILES = src/Tweak.x
AcecraftHack_CFLAGS = -fobjc-arc
AcecraftHack_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
