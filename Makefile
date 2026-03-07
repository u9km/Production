ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
# استهداف نسخة نظام مستقرة
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libwebp
libwebp_FILES = AmarShield_Zeus.mm
# استخدام -Os للتوازن المثالي في الحجم (حوالي 400KB)
libwebp_CFLAGS = -fobjc-arc -Os -fvisibility=hidden
libwebp_CXXFLAGS = -std=c++14 -Os -fvisibility=hidden -fno-rtti -fno-exceptions

# الربط مع dobby وتصفية الرموز المفضوحة
libwebp_LDFLAGS = -L. -ldobby \
                  -Wl,-install_name,@rpath/libwebp.framework/libwebp \
                  -Wl,-unexported_symbol,_Dobby* \
                  -Wl,-unexported_symbol,_Intercept* \
                  -Wl,-x -Wl,-S -dead_strip

include $(THEOS_MAKE_PATH)/library.mk
