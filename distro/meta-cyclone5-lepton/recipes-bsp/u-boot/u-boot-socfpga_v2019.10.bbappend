FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}_v2019.10:"

# Patch u-boot for GCC10 minor error
SRC_URI += " file://gcc-10-fix.patch \
           "
