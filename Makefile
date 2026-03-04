TARGET := iphone:clang:latest:14.0
ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AmarShield

# أسماء الملفات التي سيتم تجميعها
AmarShield_FILES = AmarShield_Zeus.mm fishhook.c

# المكاتب التي أضفناها لمنع الكراش (تم إضافة AdSupport لتجميد البصمة)
AmarShield_FRAMEWORKS = Foundation UIKit CoreGraphics QuartzCore Security AdSupport

# إعدادات المترجم
AmarShield_CFLAGS = -fobjc-arc
# تم التحديث لدعم أحدث تقنيات C++20 مع تفعيل تحسينات الأداء (-O2) لتسريع التشفير
AmarShield_CCFLAGS = -std=c++20 -O2

include $(THEOS_MAKE_PATH)/tweak.mk
