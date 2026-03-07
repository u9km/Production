# =================================================================
# [ إعدادات البيئة والتجميع الصارم ]
# =================================================================
DEBUG = 0
FINALPACKAGE = 1
ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AmarShield_Zeus
# تأكد من دمج ملف الفيش هوك المموه
AmarShield_Zeus_FILES = AmarShield_Zeus.mm fishhook.c

# =================================================================
# [ أعلام المترجم والرابط - إطفاء النور بالكامل ]
# =================================================================
# -g0 لمنع تسريب الـ Structs, و -O3 للتسريع
AmarShield_Zeus_CFLAGS = -fobjc-arc -fvisibility=hidden -g0 -O3
AmarShield_Zeus_CXXFLAGS = -fobjc-arc -fvisibility=hidden -fno-rtti -fno-exceptions -g0 -O3 -std=c++14

# -Wl,-x -Wl,-S لمسح جدول الرموز الوصفية بالكامل
AmarShield_Zeus_LDFLAGS = -Wl,-x -Wl,-S -dead_strip

include $(THEOS_MAKE_PATH)/tweak.mk

after-package::
	@echo "💎 [AmarShield Zeus] Compiled Successfully with Zero-Trace Flags."
