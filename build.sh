#!/usr/bin/env bash
set -e

# Define colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
clear_color='\033[0m'

# Thread management
CORES=$(nproc --all)
THREADS=$((CORES > 1 ? CORES - 1 : 1))

usage() {
    printf "${green}Usage: ${clear_color}$0 -m [laurel|gingko] [-c] [-h] [-b]\n"
    exit 1
}

SECONDS=0
topdir="$(pwd)"
tc_dir="$topdir/toolchain"
tc_url="https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/10032024/neutron-clang-10032024.tar.zst"
mkdtimg_url="https://github.com/akabul0us/mkdtimg/raw/refs/heads/static/mkdtimg"
ak3_dir="$topdir/AnyKernel3"

export KBUILD_BUILD_USER="$(whoami)"
export KBUILD_BUILD_HOST="$(hostname)"
make_options="ARCH=arm64 CC=clang AS=llvm-as CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 DTC_EXT=$tc_dir/bin/dtc"
make_prefix=""

while getopts "m:chb" opt; do
    case $opt in
    m)
        model=$OPTARG
        if [ "$model" == "laurel" ]; then
            nh_config="nethunter_laurel_sprout_defconfig"; ak3_branch="laurel_sprout"
            zipname="laurel-sprout-nethunter-$(date '+%Y%m%d-%H%M').zip"
            tarball="laurel-sprout-modules-$(date '+%Y%m%d-%H%M').tar.gz"
            dtbo="arch/arm64/boot/dts/xiaomi/laurel_sprout-trinket-overlay.dtbo"
        elif [ "$model" == "gingko" ]; then
            nh_config="nethunter_gingko_defconfig"; ak3_branch="gingko"
            zipname="gingko-nethunter-$(date '+%Y%m%d-%H%M').zip"
            tarball="gingko-modules-$(date '+%Y%m%d-%H%M').tar.gz"
            dtbo="arch/arm64/boot/dts/xiaomi/ginkgo-trinket-overlay.dtbo"
        else
            exit 1
        fi
        config_command="$nh_config"
        ;;
    c) cp "$topdir/arch/arm64/configs/$nh_config" "$topdir/.config"; config_command="nconfig" ;;
    b) make_prefix="ionice -c 3 chrt --idle 0 nice -n19" ;;
    h) usage ;;
    esac
done

if [ -z "$model" ]; then usage; fi

# Environment setup
export PATH="$tc_dir/bin:$PATH"
[ -d "$tc_dir" ] || { mkdir -p "$tc_dir"; cd "$tc_dir"; curl -fsSL "$tc_url" | tar --zstd -xf -; cd "$topdir"; }

# Build execution
printf "${green}Starting compilation with $THREADS threads...${clear_color}\n"
${make_prefix} make ${make_options} -j$THREADS $config_command
${make_prefix} make ${make_options} -j$THREADS Image Image.gz

# Verify/Generate files
cd "$topdir/arch/arm64/boot"
# If Image doesn't exist, we can decompress Image.gz to get it
[ -f "Image" ] || gzip -dkc Image.gz > Image

# Kernel Packaging
[ -d "$ak3_dir" ] || git clone https://github.com/akabul0us/AnyKernel3 -b "$ak3_branch" "$ak3_dir"
cp Image Image.gz "$ak3_dir/"

cd "$ak3_dir"
[ -f "$topdir/$dtbo" ] && mkdtimg create dtbo.img "$topdir/$dtbo"
zip -r9 "../$zipname" * -x .git README.md
printf "${green}Kernel ZIP created: $zipname${clear_color}\n"

# Modules Packaging
cd "$topdir"
printf "${yellow}Packing modules...${clear_color}\n"
mod_temp="modules_tmp"
mkdir -p "$mod_temp"
find . -name "*.ko" -exec cp {} "$mod_temp" \;

if [ "$(ls -A $mod_temp)" ]; then
    tar -czf "$tarball" -C "$mod_temp" .
    rm -rf "$mod_temp"
    printf "${green}Modules tarball created: $tarball${clear_color}\n"
else
    printf "${red}No modules found to pack.${clear_color}\n"
    rm -rf "$mod_temp"
fi

printf "\nCompleted in $((SECONDS / 60))m $((SECONDS % 60))s!\n"
