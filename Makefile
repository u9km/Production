# =================================================================
# [ إعدادات البيئة والتجميع الصارم ]
# =================================================================
DEBUG = 0
FINALPACKAGE = 1
ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AmarShield_Zeus
AmarShield_Zeus_FILES = AmarShield_Zeus.mm

# =================================================================
# [ أعلام المترجم والرابط - إطفاء النور، ربط محلي، وتزييف الهوية ]
# =================================================================
# إضافة -I. لإخبار المترجم بالبحث عن dobby.h في نفس المجلد
AmarShield_Zeus_CFLAGS = -fobjc-arc -fvisibility=hidden -g0 -O3 -I.
AmarShield_Zeus_CXXFLAGS = -fobjc-arc -fvisibility=hidden -fno-rtti -fno-exceptions -g0 -O3 -std=c++14 -I.

# إضافة -L. لإخبار الرابط بالبحث عن libdobby في نفس المجلد
AmarShield_Zeus_LDFLAGS = -Wl,-x -Wl,-S -dead_strip -L. -ldobby -Wl,-install_name,@rpath/libwebp.framework/libwebp

include $(THEOS_MAKE_PATH)/tweak.mk

after-package::
	@echo "💎 [AmarShield Zeus] Compiled Successfully with Local Dobby & libwebp Identity."
