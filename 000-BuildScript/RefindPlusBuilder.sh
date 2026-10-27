#!/usr/bin/env bash
###
 # RefindPlusBuilder.sh
 # A script to build RefindPlus
 #
 # Copyright (c) 2020-2025 Dayo Akanji
 # MIT-0 License
###

# Re-Exec with Bash if invoked via a non-Bash shell (e.g. 'sh RefindPlusBuilder.sh').
# This script relies on Bash-only features (pushd/popd, 'trap ERR', '[ x == y ]')
# and on edksetup.sh / BaseTools/BuildEnv, which are themselves Bash-only.
if [ -z "${BASH_VERSION:-}" ] ; then
    exec /usr/bin/env bash "$0" "$@"
fi

COLOR_BASE=""
COLOR_INFO=""
COLOR_STATUS=""
COLOR_ERROR=""
COLOR_NORMAL=""
GCC5_WRAPPER_DIR=""
TPUT="$(command -v tput || true)"

if test -t 1 && [ -n "${TPUT}" ]; then
    NCOLORS=$("${TPUT}" colors 2>/dev/null || true)
    if [[ "${NCOLORS}" =~ ^[0-9]+$ ]] && (( NCOLORS >= 8 )); then
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
    if [ -n "${GCC5_WRAPPER_DIR}" ] && [ -d "${GCC5_WRAPPER_DIR}" ] ; then
        rm -rf -- "${GCC5_WRAPPER_DIR}"
        GCC5_WRAPPER_DIR=""
    fi
    if [ -f "${MAKEFILE_ORIG}" ] ; then
        mv -f "${MAKEFILE_ORIG}" "${MAKEFILE_TEMP}" || true
    fi
    if [ "${WORD_WRAP}" == '0' ] ; then
        # Enable WordWrap
        if [ -n "${TPUT}" ]; then
            "${TPUT}" smam >/dev/null 2>&1 || true
        fi
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
trapERR() {
    local errStatus
    local errCommand

    errStatus="${1:-1}"
    errCommand="${2:-unknown command}"
    runErr "Runtime Error (exit ${errStatus}) in command: ${errCommand}"
}
trap 'trapERR "$?" "$BASH_COMMAND"' ERR
trap trapINT SIGINT


# Set Script Params
ORIG_PATH="${PATH}"
DONE_ONE="False"

BUILD_BRANCH="${1:-Full}"
DEBUG_TYPE="${2:-REL}"
WORD_WRAP="${3:-0}"
if [ "${WORD_WRAP}" == '0' ] ; then
    # Disable WordWrap
    if [ -n "${TPUT}" ]; then
        "${TPUT}" rmam >/dev/null 2>&1 || true
    fi
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
if [ "${BUILD_TYPE}" == 'DBG' ] || [ "${BUILD_TYPE}" == 'ALL' ] ; then
    RUN_DBG="True"
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
BASE_DIR="$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")"
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
OUR_SHASUM='/data/data/com.termux/files/usr/bin/shasum'
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
Get_Mac_Ver=""
if [ "$(uname -s)" == 'Darwin' ] ; then
    Get_Mac_Ver="$(sysctl kern.osrelease | cut -d ':' -f 2 | xargs)"
fi
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

if [ -z "${GCC5_BIN:-}" ] ; then
    GCC5_COMPILER=""
    if [ "${PREFIX:-}" != '/data/data/com.termux/files/usr' ] ; then
        GCC5_COMPILER="$(command -v x86_64-linux-gnu-gcc || true)"
        if [ -z "${GCC5_COMPILER}" ] ; then
            GCC5_COMPILER="$(command -v gcc || true)"
        fi
    fi
    if [ -n "${GCC5_COMPILER}" ] \
    && [[ "$("${GCC5_COMPILER}" -dumpmachine 2>/dev/null)" == x86_64-* ]] ; then
        GCC5_BIN="${GCC5_COMPILER%gcc}"
    else
        GCC5_CLANG="$(command -v clang || true)"
        GCC5_LLVM_AR="$(command -v llvm-ar || true)"
        GCC5_LLVM_OBJCOPY="$(command -v llvm-objcopy || true)"
        if [ -z "${GCC5_CLANG}" ] || [ -z "${GCC5_LLVM_AR}" ] \
        || [ -z "${GCC5_LLVM_OBJCOPY}" ] ; then
            runErr "ERROR: Need an X64 GCC cross-compiler or Termux clang, llvm-ar, and llvm-objcopy"
        fi

        GCC5_WRAPPER_DIR="$(mktemp -d "${TMPDIR:-/tmp}/refindplus-x64.XXXXXX")" \
            || runErr "ERROR: Could not create temporary X64 compiler wrappers"
        export GCC5_CLANG GCC5_LLVM_AR GCC5_LLVM_OBJCOPY
        GCC5_LDS="${GCC5_WRAPPER_DIR}/GccBase.lds"
        sed -e '/\*(\.got \.got\.\*)/d' \
            -e '/\*(\.data \.data\.\* \.gnu.linkonce\.d\.\*)/i\    *(.got .got.*)' \
            "${EDK2_DIR}/BaseTools/Scripts/GccBase.lds" > "${GCC5_LDS}" \
            || runErr "ERROR: Could not prepare the Termux Clang linker script"
        export GCC5_LDS
        cat > "${GCC5_WRAPPER_DIR}/tool" <<'EOF'
#!/usr/bin/env bash
case "$(basename "$0")" in
    gcc)
        if [ "$#" -eq 1 ] && [ "$1" == '-dumpmachine' ] ; then
            echo x86_64-unknown-linux-gnu
            exit 0
        fi
        args=()
        for arg in "$@"; do
            if [ "$arg" == '-Wl,-n,-q,--gc-sections' ] ; then
                arg='-Wl,-q,--gc-sections'
            elif [[ "$arg" == '-Wl,--script='*'/GccBase.lds' ]] ; then
                arg="-Wl,--script=${GCC5_LDS}"
            fi
            if [ "$arg" != '-Wl,--no-warn-rwx-segments' ] \
            && [ "$arg" != '-maccumulate-outgoing-args' ] ; then
                args+=("$arg")
            fi
        done
        exec "${GCC5_CLANG}" --target=x86_64-unknown-linux-gnu \
            -fuse-ld=lld -Qunused-arguments \
            -Wno-error=single-bit-bitfield-constant-conversion \
            -Wno-error=varargs -Wno-error=constant-conversion "${args[@]}"
        ;;
    gcc-ar)
        exec "${GCC5_LLVM_AR}" "$@"
        ;;
    objcopy)
        exec "${GCC5_LLVM_OBJCOPY}" "$@"
        ;;
esac
exit 1
EOF
        chmod +x "${GCC5_WRAPPER_DIR}/tool"
        for TOOL in gcc gcc-ar objcopy; do
            ln -s tool "${GCC5_WRAPPER_DIR}/${TOOL}"
        done
        GCC5_BIN="${GCC5_WRAPPER_DIR}/"
    fi
fi
export GCC5_BIN
GCC5_COMPILER="$(command -v "${GCC5_BIN}gcc" || true)"
if [ -z "${GCC5_COMPILER}" ] \
|| [[ "$("${GCC5_COMPILER}" -dumpmachine 2>/dev/null)" != x86_64-* ]] ; then
    runErr "ERROR: '${GCC5_BIN}gcc' is not an X64 GCC compiler"
fi
for TOOL in gcc gcc-ar objcopy; do
    if ! command -v "${GCC5_BIN}${TOOL}" > /dev/null 2>&1 ; then
        runErr "ERROR: Could not find '${GCC5_BIN}${TOOL}'"
    fi
done

if ! command -v python2 > /dev/null 2>&1 ; then
    if [ -x '/data/data/com.termux/files/usr/bin/python2' ] ; then
        export PATH="${PATH}:/data/data/com.termux/files/usr/bin"
    else
        runErr 'ERROR: Python 2 is required to build RefindPlus'
    fi
fi
if ! python2 -c 'import sys; sys.exit(0 if sys.version_info[0] == 2 else 1)' ; then
    runErr 'ERROR: python2 does not run Python 2'
fi

BUILD_THREAD_ARGS=()
if [ "${PREFIX:-}" == '/data/data/com.termux/files/usr' ] ; then
    BUILD_THREAD_ARGS=(-n 1)
fi

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
            sed -i 's|#include <ProcessorBind.h>|#include "../AArch64/ProcessorBind.h"|' "${BASETYPE_TEMP}"
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
rm -f "${EDK2_DIR}/Conf/BuildEnv.sh"
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
    build "${BUILD_THREAD_ARGS[@]}" -a X64 -b RELEASE -t GCC5 -p RefindPlusPkg/RefindPlusPkg.dsc
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
    build "${BUILD_THREAD_ARGS[@]}" -a X64 -b DEBUG -t GCC5 -p RefindPlusPkg/RefindPlusPkg.dsc
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
    build "${BUILD_THREAD_ARGS[@]}" -a X64 -b NOOPT -t GCC5 -p RefindPlusPkg/RefindPlusPkg.dsc
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
