#!/usr/bin/env bash

set -eu -o pipefail
# set -o xtrace

# Download GCC ARM64 toolchain from
#   https://developer.arm.com/-/media/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-aarch64-none-elf.tar.xz
# Extract it somewhere to disk, e.g.
#   tar -C /opt/ -xvf gcc-arm-10.3-2021.07-x86_64-aarch64-none-elf.tar.xz
# Provide the full path here:
GCC_ARM="/opt/gcc-arm-10.3-2021.07-x86_64-aarch64-none-elf/"

# Download MCom-03 SDK from
#   https://dist.elvees.com/mcom03/buildroot/2022.06/rockpi/images/aarch64-buildroot-linux-gnu_sdk-buildroot.tar.gz
# Extract it somewhere to disk, e.g.
#   tar -C /opt/ -xvzf aarch64-buildroot-linux-gnu_sdk-buildroot.tar.gz \
#   aarch64-buildroot-linux-gnu_sdk-buildroot/opt/toolchain-mipsel-elvees-elf32/ --strip-components=2
# and provide the full path here:
GCC_MIPS="/opt/toolchain-mipsel-elvees-elf32/"

function dl_repo()
{
    mkdir -p bin
    curl https://storage.googleapis.com/git-repo-downloads/repo > bin/repo
    chmod 0755 bin/repo
}

function dl_src()
{
    bin/repo init -u https://github.com/dpetrov-rts/mcom03-sbl-build \
        -b master -m default.xml
    bin/repo sync
}

function set_env_arm()
{
    export ARCH=aarch64
    export SYSROOT="${GCC_ARM}"
    export CROSS_COMPILE="${SYSROOT}/bin/aarch64-none-elf-"
    export CFLAGS="-Wno-misleading-indentation -Wno-int-to-pointer-cast -Wno-pointer-to-int-cast -I${SYSROOT}/include "
    export LDFLAGS="-L${SYSROOT}/lib -L${SYSROOT}/lib64"
    export CC=${CROSS_COMPILE}gcc
    export CXX=${CROSS_COMPILE}g++
    export CPP=${CROSS_COMPILE}cpp
    export LD=${CROSS_COMPILE}ld
    export AS=${CROSS_COMPILE}as
    export ASM=${CROSS_COMPILE}as
}

function set_env_mips()
{
    export ARCH=mips
    export SYSROOT="${GCC_MIPS}"
    export CROSS_COMPILE="${SYSROOT}/bin/mipsel-elf32-"
    export CFLAGS="-Wno-misleading-indentation -Wno-int-to-pointer-cast -Wno-pointer-to-int-cast -I${SYSROOT}/include -I${SYSROOT}/usr/include "
    export LDFLAGS="-L${SYSROOT}/lib -L${SYSROOT}/usr/lib -L${SYSROOT}/lib64 -L${SYSROOT}/local/lib"
    export CC=${CROSS_COMPILE}gcc
    export CXX=${CROSS_COMPILE}g++
    export CPP=${CROSS_COMPILE}cpp
    export LD=${CROSS_COMPILE}ld
    export AS=${CROSS_COMPILE}as
    export ASM=${CROSS_COMPILE}as
}

function unset_env()
{
    unset ARCH SYSROOT CROSS_COMPILE CFLAGS LDFLAGS CC CXX CPP LD AS ASM
}

function build_ddrinit()
{
    echo
    echo '----------------------'
    echo 'DDR Init'
    echo '----------------------'
    pushd sources/ddrinit
    set_env_mips
    pip3 install pipenv --user
    export PATH=~/.local/bin:$PATH
    export LANG="en_US.UTF-8"
    pipenv install --dev
    pipenv run make elvmc03smarc_defconfig
    pipenv run make clean
    pipenv run make
    # out: sources/ddrinit/src/ddrinit.{bin,elf}
    popd
    echo '----------------------'
    echo 'DDR Init: OK'
    echo '----------------------'
}

function build_atf()
{
    echo
    echo '----------------------'
    echo 'Trusted Firmware-A'
    echo '----------------------'
    pushd sources/arm-trusted-firmware
    set_env_arm
    make PLAT=mcom03 clean bl31
    # out: sources/arm-trusted-firmware/build/mcom03/release/bl31.bin
    popd
    echo '----------------------'
    echo 'Trusted Firmware-A: OK'
    echo '----------------------'
}

function build_uboot()
{
    echo
    echo '----------------------'
    echo 'Das U-Boot'
    echo '----------------------'
    pushd sources/u-boot
    set_env_arm
    make clean
    make elvmc03smarc-rockpi_defconfig
    make -j "$(nproc)" u-boot.bin
    # out: sources/u-boot/u-boot.bin
    popd
    echo '----------------------'
    echo 'Das U-Boot: OK'
    echo '----------------------'
}

function build_mcom03_sbl()
{
    echo
    echo '----------------------'
    echo 'MCom-03 SBL'
    echo '----------------------'
    pushd sources/mcom03-sbl
    unset_env
    mkdir -p build && cd build
    cp ../link.ld .
    cmake .. \
        -DCMAKE_TRY_COMPILE_TARGET_TYPE="STATIC_LIBRARY" \
        -DDDRINIT_PATH=../../ddrinit/src/ddrinit.bin \
        -DTFA_PATH=../../arm-trusted-firmware/build/mcom03/release/bl31.bin \
        -DUBOOT_PATH=../../u-boot/u-boot.bin \
        -DCMAKE_TOOLCHAIN_FILE="${GCC_MIPS}/share/cmake/toolchain.cmake"
    cmake --build . --target clean
    cmake --build .
    # out: sources/mcom03-sbl/build/sbl.bin
    popd
    echo '----------------------'
    echo 'MCom-03 SBL: OK'
    echo '----------------------'
}

dl_repo
dl_src
build_ddrinit
build_atf
build_uboot
build_mcom03_sbl
unset_env
