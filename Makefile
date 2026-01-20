TARGET := iphone:clang:latest:7.0
INSTALL_TARGET_PROCESSES = ACECRAFT

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AcecraftHack

AcecraftHack_FILES = src/Tweak.x
AcecraftHack_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
