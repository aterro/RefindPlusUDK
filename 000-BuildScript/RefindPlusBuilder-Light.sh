#!/usr/bin/env bash
###
 # RefindPlusBuilder.sh
 # A script to build RefindPlus
 #
 # Copyright (c) 2020-2025 Dayo Akanji
 # MIT-0 License
###

COLOR_BASE=""
COLOR_INFO=""
COLOR_STATUS=""
COLOR_ERROR=""
COLOR_NORMAL=""

if test -t 1; then
    NCOLORS=$(tput colors)
    if test -n "${NCOLORS}" && test "${NCOLORS}" -ge 8; then
        COLOR_BASE="\033[0;36m"
        COLOR_INFO="\033[0;33m"
        COLOR_STATUS="\033[0;32m"
        COLOR_ERROR="\033[0;31m"
        COLOR_NORMAL="\033[0m"
    fi
fi

# Provide custom colours
msg_base() {
    printf "${COLOR_BASE}${1}${COLOR_NORMAL}\n"
}
msg_info() {
    printf "${COLOR_INFO}${1}${COLOR_NORMAL}\n"
}
msg_status() {
    printf "${COLOR_STATUS}${1}${COLOR_NORMAL}\n"
}
msg_error() {
    printf "${COLOR_ERROR}${1}${COLOR_NORMAL}\n"
}

## REVERT WORD_WRAP FIX ##
RevertWordWrap() {
    export PATH="${ORIG_PATH}";
    if [ -f "${MAKEFILE_ORIG}" ] ; then
        mv -f "${MAKEFILE_ORIG}" "${MAKEFILE_TEMP}" || true
    fi
    if [ "${WORD_WRAP}" == '0' ] ; then
        # Enable WordWrap
        tput smam
    fi
}

## ERROR HANDLERS ##
trapINT() { # $1: message
    # Declare Local Variables
    local errMessage

    # Revert Word Wrap Fix
    RevertWordWrap ;

    # SHow error and exit
    errMessage="${1:-Force Quit ... Exiting}"
    echo ''
    msg_error "${errMessage}"
    echo ''
    echo ''
    exit 1
}

runErr() { # $1: message
    # Declare Local Variables
    local errMessage

    # Revert Word Wrap Fix
    RevertWordWrap ;

    # Show error and exit
    errMessage="${1:-Runtime Error ... Exiting}"
    echo ''
    msg_error "${errMessage}"
    echo ''
    echo ''
    exit 1
}
trap runErr ERR
trap trapINT SIGINT


# Set Script Params
ORIG_PATH="${PATH}"
DONE_ONE="False"

BUILD_BRANCH="${1:-GOPFix}"
DEBUG_TYPE="${2:-SOME}"
WORD_WRAP="${3:-0}"
if [ "${WORD_WRAP}" == '0' ] ; then
    # Disable WordWrap
    tput rmam
fi

RUN_REL="True"
RUN_DBG="False"
RUN_NPT="False"
BUILD_TYPE=$( echo $DEBUG_TYPE | tr '[:lower:]' '[:upper:]' )
if [ "${BUILD_TYPE}" == 'DBG' ] || [ "${BUILD_TYPE}" == 'NPT' ] ; then
    RUN_REL="False"
fi
if [ "${BUILD_TYPE}" == 'REL' ] || [ "${BUILD_TYPE}" == 'NPT' ] ; then
    RUN_DBG="False"
fi
if [ "${BUILD_TYPE}" == 'ALL' ] || [ "${BUILD_TYPE}" == 'NPT' ] \
|| ([ "${BUILD_TYPE}" != 'REL' ] && [ "${BUILD_TYPE}" != 'DBG' ] && \
    [ "${BUILD_TYPE}" != 'SOME' ]) ; then
    RUN_NPT="True"
fi


# Set things up for build
clear
msg_info "## RefindPlusBuilder - Setting Up ##  :  ${BUILD_BRANCH}"
msg_info '##--------------------------------##'
BASE_DIR="${HOME}/Documents/RefindPlus"
WORK_DIR="${BASE_DIR}/Working"
EDK2_DIR="${BASE_DIR}/edk2"
if [ ! -d "${EDK2_DIR}" ] ; then
    runErr "ERROR: Could not locate ${EDK2_DIR}"
fi
XCODE_DIR_REL="${EDK2_DIR}/Build/RefindPlus/RELEASE_GCC5"
XCODE_DIR_DBG="${EDK2_DIR}/Build/RefindPlus/DEBUG_GCC5"
XCODE_DIR_NPT="${EDK2_DIR}/Build/RefindPlus/NOOPT_GCC5"
BINARY_DIR_REL="${XCODE_DIR_REL}/X64"
BINARY_DIR_DBG="${XCODE_DIR_DBG}/X64"
BINARY_DIR_NPT="${XCODE_DIR_NPT}/X64"
OUTPUT_DIR="${EDK2_DIR}/000-BOOTx64-Files"
OUR_SHASUM='/usr/bin/shasum'
MAKEFILE_TEMP="${EDK2_DIR}/BaseTools/Source/C/Makefiles/header.makefile"
MAKEFILE_ORIG="${EDK2_DIR}/BaseTools/Source/C/Makefiles/header-orig.makefile"
BASETYPE_TEMP="${EDK2_DIR}/BaseTools/Source/C/Include/Common/BaseTypes.h"
BASETYPE_ORIG="${EDK2_DIR}/BaseTools/Source/C/Include/Common/BaseTypes-orig.h"

ErrMsg="ERROR: Could not find '${EDK2_DIR}/BaseTools'"
pushd "${EDK2_DIR}/BaseTools" > /dev/null || runErr "${ErrMsg}"
BASETOOLS_SHA_FILE="${EDK2_DIR}/000-BuildScript/BaseToolsSHA.txt"
if [ ! -f "${BASETOOLS_SHA_FILE}" ] ; then
    BASETOOLS_SHA_OLD='Default'
else
    # shellcheck disable=SC1090
    source "${BASETOOLS_SHA_FILE}" || BASETOOLS_SHA_OLD='Default'
fi
Get_Sha_Str="$(find "${EDK2_DIR}/BaseTools" "${EDK2_DIR}/Conf" \
  -type f \( -name '*.c' -or -name '*.cpp' -or -name '*.h' -or -name '*.py' -or \
  -name '*.txt' -or -name '*.template' -or -name '*.makefile' -or -name 'GNUmakefile' \) \
  -print0 | sort -z | xargs -0 ${OUR_SHASUM} | ${OUR_SHASUM} | cut -d ' ' -f 1)"
Get_Mac_Ver="$( sysctl kern.osrelease | cut -d ':' -f 2 | xargs )"
BASETOOLS_SHA_NEW="${Get_Sha_Str}:${Get_Mac_Ver}"
BUILD_TOOLS='false'
if [ ! -d "${EDK2_DIR}/BaseTools/Source/C/bin" ] \
|| [ "${BASETOOLS_SHA_NEW}" != "${BASETOOLS_SHA_OLD}" ] ; then
    BUILD_TOOLS='true'
    if [ -f "${BASETOOLS_SHA_FILE}" ] ; then
        rm -f "${BASETOOLS_SHA_FILE}"
    fi
fi
popd > /dev/null || true

msg_base 'Export Temp "PATH"...'
export PATH="/usr/bin:/opt/local/bin:/opt/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:${PATH}"
msg_status '...OK'; echo ''

ErrMsg="ERROR: Could not find '${WORK_DIR}'"
pushd "${WORK_DIR}" > /dev/null || runErr "${ErrMsg}"
msg_base "Checkout '${BUILD_BRANCH}' branch..."
git checkout ${BUILD_BRANCH} > /dev/null
popd > /dev/null || true
msg_status '...OK'; echo ''

msg_base 'Update RefindPlusPkg...'
# Remove Later - START #
rm -fr "${EDK2_DIR}/RefindPkg"
rm -fr "${EDK2_DIR}/.Build-TMP"
# Remove Later - END #
if [ ! -L "${EDK2_DIR}/RefindPlusPkg" ]; then
	rm -fr "${EDK2_DIR}/RefindPlusPkg"
    ln -s "${WORK_DIR}" "${EDK2_DIR}/RefindPlusPkg"
fi
msg_status '...OK'; echo ''

# Enter EDK2 Dir - START #
ErrMsg="ERROR: Could not enter '${EDK2_DIR}'"
pushd "${EDK2_DIR}" > /dev/null || runErr "${ErrMsg}"
if [ "${BUILD_TOOLS}" == 'true' ] ; then
    ErrMsg="ERROR: Could not find '${EDK2_DIR}/BaseTools/Source/C'"
    pushd "${EDK2_DIR}/BaseTools/Source/C" > /dev/null || runErr "${ErrMsg}"
    msg_base 'Make Clean...'
    make clean
    msg_status '...OK'; echo ''
    popd > /dev/null || true

    OurArch="$(uname -m)"
    if [[ "${OurArch}" == *"arm"* ]] ; then
        msg_base 'Create Temp BaseTools BaseType for Apple Silicon...'
        if [ -f "${BASETYPE_ORIG}" ] ; then
            cp -f "${BASETYPE_ORIG}" "${BASETYPE_TEMP}"
        else
            cp -f "${BASETYPE_TEMP}" "${BASETYPE_ORIG}"
        fi

        # Apply patch if not already patched
        if grep -q '#include <ProcessorBind.h>' "${BASETYPE_TEMP}"; then
            sed -i '' 's|#include <ProcessorBind.h>|#include "../AArch64/ProcessorBind.h"|' "${BASETYPE_TEMP}"
        fi
        msg_status '...OK'; echo ''

        msg_base 'Create Temp BaseTools Makefile for Apple Silicon...'
        if [ -f "${MAKEFILE_ORIG}" ] ; then
            cp -f "${MAKEFILE_ORIG}" "${MAKEFILE_TEMP}"
        else
            cp -f "${MAKEFILE_TEMP}" "${MAKEFILE_ORIG}"
        fi
        CFLAGS=-Wno-pointer-to-int-cast
        BUILD_CFLAGS+=($CFLAGS)
        BUILD_CXXFLAGS+=($CFLAGS)
        #CC_FLAGS+=($CFLAGS)
        (
            echo ""
            echo "BUILD_CFLAGS += $BUILD_CFLAGS"
            echo "BUILD_CXXFLAGS += $BUILD_CXXFLAGS"
        ) >> "${MAKEFILE_TEMP}"
        msg_status '...OK'; echo ''
    fi

    msg_base 'Make BaseTools...'
    make -C BaseTools/Source/C
    echo '#!/usr/bin/env bash' > "${BASETOOLS_SHA_FILE}"
    echo "BASETOOLS_SHA_OLD='${BASETOOLS_SHA_NEW}'" >> "${BASETOOLS_SHA_FILE}"
    msg_status '...OK'; echo ''

    msg_base 'Update BaseTools SHA...'
    echo '#!/usr/bin/env bash' > "${BASETOOLS_SHA_FILE}"
    echo "BASETOOLS_SHA_OLD='${BASETOOLS_SHA_NEW}'" >> "${BASETOOLS_SHA_FILE}"
    msg_status '...OK'; echo ''

    if [[ "${OurArch}" == *"arm"* ]] ; then
        if [ -f "${BASETYPE_ORIG}" ] ; then
            msg_base 'Discard Temp BaseType...'
            mv -f "${BASETYPE_ORIG}" "${BASETYPE_TEMP}" || true
            msg_status '...OK'; echo ''
        fi

        if [ -f "${MAKEFILE_ORIG}" ] ; then
            msg_base 'Discard Temp Makefile...'
            mv -f "${MAKEFILE_ORIG}" "${MAKEFILE_TEMP}" || true
            msg_status '...OK'; echo ''
        fi
    fi
fi
popd > /dev/null || true
# Enter EDK2 Dir - END #

# Basic clean up
echo ''
clear
msg_info "## RefindPlusBuilder - Initial Clean Up ##  :  ${BUILD_BRANCH}"
msg_info '##--------------------------------------##'
msg_base 'Misc Item Fixup...'
rm -fr "${EDK2_DIR}/Build"
rm -fr "${OUTPUT_DIR}"
mkdir -p "${EDK2_DIR}/Build"
mkdir -p "${OUTPUT_DIR}"
msg_status '...OK'; echo ''

# Build RELEASE version
if [ "${RUN_REL}" == 'True' ] ; then
    echo ''
    clear
    msg_info "## RefindPlusBuilder - Building REL Version ##  :  ${BUILD_BRANCH}"
    msg_info '##------------------------------------------##'
    ErrMsg="ERROR: Could not find '${EDK2_DIR}'"
    pushd "${EDK2_DIR}" > /dev/null || runErr "${ErrMsg}"
    source edksetup.sh BaseTools
    build -a X64 -b RELEASE -t GCC5 -p RefindPlusPkg/RefindPlusPkg.dsc
    if [ -d "${EDK2_DIR}/Build" ] ; then
        cp "${BINARY_DIR_REL}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-REL.efi"
    fi
    for file in "${BINARY_DIR_REL}"/*.efi; do
        filetag=$(basename "${file%.efi}")
        if [[ "${filetag}" == 'gptsync' || "${filetag}" == 'RefindPlus' ]]; then
            mv "${file}" "${BINARY_DIR_REL}/x64_${filetag}_REL.efi"
        else
            mv "${file}" "${BINARY_DIR_REL}/DRIVER_REL--x64_${filetag}.efi"
        fi
    done
    popd > /dev/null || true
    echo ''
    msg_info "Completed REL Build on '${BUILD_BRANCH}' Branch of RefindPlus"
    DONE_ONE="True"
fi


# Build DEBUG version
if [ "${RUN_DBG}" == 'True' ] ; then
    if [ "${DONE_ONE}" == 'True' ] ; then
        msg_info 'Preparing DBG Build...'
        echo ''
        sleep 4
    fi

    clear
    msg_info "## RefindPlusBuilder - Building DBG Version ##  :  ${BUILD_BRANCH}"
    msg_info '##------------------------------------------##'
    ErrMsg="ERROR: Could not find '${EDK2_DIR}'"
    pushd "${EDK2_DIR}" > /dev/null || runErr "${ErrMsg}"
    source edksetup.sh BaseTools
    build -a X64 -b DEBUG -t GCC5 -p RefindPlusPkg/RefindPlusPkg.dsc
    if [ -d "${EDK2_DIR}/Build" ] ; then
        cp -f "${BINARY_DIR_DBG}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-DBG.efi"
    fi
    for file in "${BINARY_DIR_DBG}"/*.efi; do
        filetag=$(basename "${file%.efi}")
        if [[ "${filetag}" == 'gptsync' || "${filetag}" == 'RefindPlus' ]]; then
            mv "${file}" "${BINARY_DIR_DBG}/x64_${filetag}_DBG.efi"
        else
            mv "${file}" "${BINARY_DIR_DBG}/DRIVER_DBG--x64_${filetag}.efi"
        fi
    done
    popd > /dev/null || true
    echo ''
    msg_info "Completed DBG Build on '${BUILD_BRANCH}' Branch of RefindPlus"
    DONE_ONE="True"
fi


# Build NOOPT version
if [ "${RUN_NPT}" == 'True' ] ; then
    if [ "${DONE_ONE}" == 'True' ] ; then
        msg_info 'Preparing NPT Build...'
        echo ''
        sleep 4
    fi

    clear
    msg_info "## RefindPlusBuilder - Building NPT Version ##  :  ${BUILD_BRANCH}"
    msg_info '##------------------------------------------##'
    ErrMsg="ERROR: Could not find '${EDK2_DIR}'"
    pushd "${EDK2_DIR}" > /dev/null || runErr "${ErrMsg}"
    source edksetup.sh BaseTools
    build -a X64 -b NOOPT -t GCC5 -p RefindPlusPkg/RefindPlusPkg.dsc
    if [ -d "${EDK2_DIR}/Build" ] ; then
        cp -f "${BINARY_DIR_NPT}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-NPT.efi"
    fi
    for file in "${BINARY_DIR_NPT}"/*.efi; do
        filetag=$(basename "${file%.efi}")
        if [[ "${filetag}" == 'gptsync' || "${filetag}" == 'RefindPlus' ]]; then
            mv "${file}" "${BINARY_DIR_NPT}/x64_${filetag}_NPT.efi"
        else
            mv "${file}" "${BINARY_DIR_NPT}/DRIVER_NPT--x64_${filetag}.efi"
        fi
    done
    popd > /dev/null || true
    echo ''
    msg_info "Completed NPT Build on '${BUILD_BRANCH}' Branch of RefindPlus"
    DONE_ONE="True"
fi


# Tidy up
echo ''
echo ''
msg_info 'Locate the EFI Files:'
if [ -d "${EDK2_DIR}/Build" ] ; then
    msg_status "RefindPlus EFI Files (BOOTx64)      : '${OUTPUT_DIR}'"
fi
if [ "${RUN_NPT}" == 'True' ] ; then
    msg_status "RefindPlus EFI Files (Others - NPT) : '${XCODE_DIR_NPT}/X64'"
fi
if [ "${RUN_DBG}" == 'True' ] ; then
    msg_status "RefindPlus EFI Files (Others - DBG) : '${XCODE_DIR_DBG}/X64'"
fi
if [ "${RUN_REL}" == 'True' ] ; then
    msg_status "RefindPlus EFI Files (Others - REL) : '${XCODE_DIR_REL}/X64'"
fi
echo ''
echo ''

# Revert Word Wrap Fix
RevertWordWrap ;
