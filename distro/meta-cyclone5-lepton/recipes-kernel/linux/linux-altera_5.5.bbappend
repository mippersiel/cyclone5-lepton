FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}_5.5:"

# Patch kernel for GCC10 minor error
SRC_URI += " file://gcc-10-fix.patch \
           "
