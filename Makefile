ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AmarShield_Zeus

AmarShield_Zeus_FILES = AmarShield_Zeus.mm
AmarShield_Zeus_CFLAGS = -fobjc-arc -Wno-error -Wno-unused-variable -Wno-unused-function
AmarShield_Zeus_CCFLAGS = -std=c++14 -Wno-error -Wno-unused-variable -Wno-unused-function
AmarShield_Zeus_FRAMEWORKS = Foundation UIKit Security LocalAuthentication
AmarShield_Zeus_LIBRARIES = crypto ssl

include $(THEOS_MAKE_PATH)/tweak.mk
