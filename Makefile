TARGET = iphone:clang:9.2

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BetterSwishSearch
BetterSwishSearch_FILES = Tweak.xm $(wildcard *.m)

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Swish"
