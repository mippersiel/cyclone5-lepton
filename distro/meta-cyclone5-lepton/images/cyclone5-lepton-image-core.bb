# Cyclone5 lepton image definition
#
SUMMARY = "Cyclone5 lepton image"

LICENSE = "GPLv3"

require conf/distro/include/cyclone5-lepton-image-base.inc

inherit core-image

# Common packages
require images/cyclone5-lepton-image-core.inc

# Specific packages
IMAGE_INSTALL += " \
                 "
