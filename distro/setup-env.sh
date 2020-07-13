#!/bin/sh
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Colored output constants
BOLD='\033[1m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color (Reset)

# Git Configuration
POKY_SHA1="4a2370583b5124ed654b41076e2701ce6bf15132"
META_OE_SHA1="e93d527a33a4bfbd704d84a4380928a23b71782a"
META_ALTERA_SHA1="363a3f924277d47ebed3cf93a4fbbd59bc25018d"

# Project Configuration
DISTRO_LAYER="${SCRIPT_DIR}/meta-cyclone5-lepton"
TARGET_MACHINES="$(ls "${DISTRO_LAYER}/conf/machine/"*.conf | sed 's|.*/\(.*\)\.conf|\1|')"

usage()
{
   echo 'Usage: . setup-env <-m machine>'
   if [ -n "${TARGET_MACHINES}" ]; then
      echo "    Supported machines: ${TARGET_MACHINES}"
   fi
   echo '    Optional parameters:
   * [-j jobs]:  number of jobs for make to spawn during the compilation stage.
   * [-t tasks]: number of BitBake tasks that can be issued in parallel.
   * [-c path]:  non-default path of SSTATE_DIR (shared state Cache)
   * [-b path]:  non-default path of build folder (build_${machine})
   * [-h]:       help
   '
}

if [ "${#}" -lt 2 ]; then
   usage
   exit 1
fi

# Default options
setup_jobs=''
setup_tasks=''
build_location=''
sstate_location=''
downloads_location=''

# Get command line options
while getopts "m:j:t:b:c:d:h" opt; do
   case "${opt}" in
      m)
         MACHINE="${OPTARG}";
         ;;
      j)
         setup_jobs="${OPTARG}";
         ;;
      t)
         setup_tasks="${OPTARG}";
         ;;
      h)
         usage
         exit 1
         ;;
      b)
         build_location="${OPTARG}";
         ;;
      c)
         sstate_location="${OPTARG}";
         ;;
      d)
         downloads_location="${OPTARG}";
         ;;
      ?)
         usage
         exit 1
         ;;
   esac
done
shift "$((OPTIND-1))"

# Check machine name
if [ -e "${DISTRO_LAYER}/conf/machine/${MACHINE}.conf" ]; then
    DISTRO="cyclone5-lepton"
    APPEND_LAYER_LIST=" \
        meta-cyclone5-lepton \
        meta-altera \
        meta-openembedded/meta-oe \
        meta-openembedded/meta-python \
        meta-openembedded/meta-networking \
    "
else
    echo "ERROR: Invalid machine type" 1>&2
    usage
    exit 1
fi

# Check if some meta are present, if not, get them
if [ ! -e poky ]; then
   echo 'Cloning poky...'
   git clone git://git.yoctoproject.org/poky.git > /dev/null 2>&1
   pushd poky > /dev/null
   git checkout "${POKY_SHA1}"
   popd > /dev/null
fi
if [ ! -e meta-openembedded ]; then
   echo 'Cloning meta-openembedded...'
   git clone https://github.com/openembedded/meta-openembedded.git > /dev/null 2>&1
   pushd meta-openembedded > /dev/null
   git checkout "${META_OE_SHA1}"
   popd > /dev/null
fi
if [ ! -e meta-altera ]; then
   echo 'Cloning meta-altera...'
   git clone https://github.com/kraj/meta-altera.git > /dev/null 2>&1
   pushd meta-altera > /dev/null
   git checkout "${META_ALTERA_SHA1}"
   popd > /dev/null
fi

# Set default jobs and tasks and check optional params
CPUS="$(grep --count processor /proc/cpuinfo)"
JOBS="${CPUS}"
THREADS="${CPUS}"

# Jobs
if [ ! -z "${setup_jobs}" ]; then
   if echo "${setup_jobs}" | grep --quiet '^[0-9]\+$'; then
      JOBS="${setup_jobs}"
   else
      echo -e "${BOLD}${YELLOW}WARNING: Invalid jobs option '${setup_jobs}', using default '${JOBS}'${NC}"
   fi
fi

# Tasks
if [ ! -z "${setup_tasks}" ]; then
   if echo "${setup_tasks}" | grep --quiet '^[0-9]\+$'; then
      THREADS="${setup_tasks}"
   else
      echo -e "${BOLD}${YELLOW}WARNING: Invalid tasks option '${setup_tasks}', using default '${JOBS}'${NC}"
   fi
fi

# Set folder location and create them if needed

# Build folder
if [ ! -z "${build_location}" ]; then
   BUILD_DIR="${build_location}"
else
   BUILD_DIR="${SCRIPT_DIR}/build_${MACHINE}"
fi
BUILD_DIR="$(readlink -f "${BUILD_DIR}")"
mkdir -p "${BUILD_DIR}"

# sstate folder
if [ ! -z "${sstate_location}" ]; then
   SSTATE_CACHE_DIR="${sstate_location}"
else
   SSTATE_CACHE_DIR="${SCRIPT_DIR}/bb_cache/sstate-cache"
fi
mkdir -p "${SSTATE_CACHE_DIR}"
SSTATE_CACHE_DIR="$(readlink -f "${SSTATE_CACHE_DIR}")"

# downloads folder
if [ ! -z "${downloads_location}" ]; then
   DOWNLOADS_DIR="${downloads_location}"
else
   DOWNLOADS_DIR="${SCRIPT_DIR}/bb_cache/downloads"
fi
DOWNLOADS_DIR="$(readlink -f "${DOWNLOADS_DIR}")"
mkdir -p "${DOWNLOADS_DIR}"


# Check if build folder was created before
if [ -e "${BUILD_DIR}/source_me" ]; then
    echo "${BUILD_DIR} was created before."
    echo "source '${BUILD_DIR}/source_me' to load build environment"
    echo "Modify files under ${BUILD_DIR}/conf/ to update."
    exit 0
fi

# Source oe-init-build-env to init build env
cd "${SCRIPT_DIR}/poky"
set -- "${BUILD_DIR}"
. ./oe-init-build-env > /dev/null

# Check result of sourcing oe-init-build-env
if [ "$(pwd -P)" != "${BUILDDIR}" ];then
   echo -e "${BOLD}${RED}ERROR: Sourcing 'oe-init-build-env' from poky repository${NC}" 1>&2
   exit 1
fi

# Add layers
for layer in $(echo "${APPEND_LAYER_LIST}"); do
   if [ -e "${SCRIPT_DIR}/${layer}" ]; then
      append_layer="$(readlink -f "${SCRIPT_DIR}/${layer}")"
      awk '# Init
           BEGIN {inSection=0}

           # Locate BBLAYERS section
           /^\s*BBLAYERS/ {inSection=1; print; next}

           # When in section, find last double quote line, append new layer followed by a backslash, place line afterwards and exit
           inSection && /\s*"/ {print "  '"${append_layer}"' \\\n" $0; exit}

           # Print every other line of no interest
           {print}' conf/bblayers.conf > conf/bblayers.conf~
      mv conf/bblayers.conf~ conf/bblayers.conf
   else
      echo -e "${BOLD}${YELLOW}WARNING: Layer '${SCRIPT_DIR}/${layer}' doesn't exist, skipping...${NC}"
   fi
done

cat >> conf/local.conf <<-EOF
MACHINE ?= "${MACHINE}"
DISTRO = "${DISTRO}"
# Package config
PACKAGE_CLASSES = "package_ipk"
# Parallelism Options
BB_NUMBER_THREADS = "${THREADS}"
PARALLEL_MAKE = "-j ${JOBS}"
# Directory config
DL_DIR = "${DOWNLOADS_DIR}"
SSTATE_DIR = "${SSTATE_CACHE_DIR}"
LICENSE_FLAGS_WHITELIST = "commercial"
KCONF_AUDIT_LEVEL = "0"
# Project environment variables
export REPO_ROOT_DIR="${SCRIPT_DIR}/.."
EOF

# Make a source_me file
if [ ! -e source_me ]; then
    echo "#!/bin/sh" >> source_me
    echo "cd ${SCRIPT_DIR}/poky" >> source_me
    echo "set -- ${BUILD_DIR}" >> source_me
    echo ". ./oe-init-build-env > /dev/null" >> source_me
    echo "echo 'Back to build project ${BUILD_DIR}'" >> source_me
fi

# Everything went well, output info on build commands and go to build directory
echo "Run one of the following command(s) to start a build:"
for img in "$(find "${DISTRO_LAYER}/images" -name '*.bb')"; do
   img=${img##*/} # Strip out path to bb file
   img=${img%.bb} # Strip out bb extension
   echo "    bitbake ${img}"
done
echo "To return to this build environment later please run:"
echo "    . ${BUILD_DIR}/source_me"
cd "${BUILD_DIR}"
