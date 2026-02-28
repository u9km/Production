TARGET := iphone:clang:latest:14.0
ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AmarShield

# أسماء الملفات التي سيتم تجميعها
AmarShield_FILES = AmarShield_Zeus.mm fishhook.c

# المكاتب التي أضفناها لمنع الكراش (CoreGraphics و QuartzCore مهمة للزر)
AmarShield_FRAMEWORKS = Foundation UIKit CoreGraphics QuartzCore Security

# إعدادات المترجم
AmarShield_CFLAGS = -fobjc-arc
AmarShield_CCFLAGS = -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk

