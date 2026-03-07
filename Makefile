ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libwebp
libwebp_FILES = AmarShield_Zeus.mm
libwebp_CFLAGS = -fobjc-arc -Os -fvisibility=hidden
libwebp_CXXFLAGS = -std=c++14 -Os -fvisibility=hidden -fno-rtti -fno-exceptions

# الربط المباشر مع مكتبة dobby المحلية لرفع الحجم للقدر الطبيعي ومسح الرموز
libwebp_LDFLAGS = -L. -ldobby \
                  -Wl,-install_name,@rpath/libwebp.framework/libwebp \
                  -Wl,-unexported_symbol,_Dobby* \
                  -Wl,-unexported_symbol,_Intercept* \
                  -Wl,-x -Wl,-S -dead_strip

include $(THEOS_MAKE_PATH)/library.mk
