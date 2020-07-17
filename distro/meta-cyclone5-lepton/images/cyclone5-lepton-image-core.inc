# Common/core packages list

MISC_PKGS = " \
   vim \
   wget \
   curl \
"

NETWORK_PKGS = " \
   iptables \
   ethtool \
   net-tools \
   openssh \
   libpam \
"

GFX_PKGS = " \
"

DEV_PKGS = " \
"

# Append all packages to image
IMAGE_INSTALL += " \
   ${MISC_PKGS} \
   ${NETWORK_PKGS} \
   ${GFX_PKGS} \
   ${DEV_PKGS} \
"

IMAGE_FEATURES += " package-management "
