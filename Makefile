TARGET := iphone:clang:latest:12.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = ACECRAFT

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AcecraftHack

AcecraftHack_FILES = src/Tweak.xm
AcecraftHack_CFLAGS = -fobjc-arc -Isrc/Il2CppLocal -std=c++17
AcecraftHack_FRAMEWORKS = UIKit Foundation CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk
