TARGET := iphone:clang:latest:14.5
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = ACECRAFT

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AcecraftHack

AcecraftHack_FILES = src/Tweak.x
AcecraftHack_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
