#!/usr/bin/env bash

#define colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
clear_color='\033[0m'

#help output
usage() {
	printf "${green}Usage: ${clear_color}$0 -m [laurel|gingko] [-c] [-h] [-b]\n"
	printf "${green}-m: ${clear_color} model to build for, Xiaomi Mi A3 (laurel) or Redmi Note 8 (gingko) ${red}(mandatory flag)${clear_color}\n"
	printf "${green}-h: ${clear_color}display this help message\n"
	printf "${green}-c: ${clear_color}configure the kernel instead of using the Nethunter defconfig\n"
	printf "${green}-b: ${clear_color}give the build a lower priority (allowing you to continue to use your computer during build) \n"
	exit 1
}
SECONDS=0 # built-in bash timer
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
			nh_config="nethunter_laurel_sprout_defconfig"
			ak3_branch="laurel_sprout"
			zipname="laurel-sprout-nethunter-$(date '+%Y%m%d-%H%M').zip"
			tarball="laurel-sprout-modules-$(date '+%Y%m%d-%H%M').tar"
			dtbo="arch/arm64/boot/dts/xiaomi/laurel_sprout-trinket-overlay.dtbo"
		elif [ "$model" == "gingko" ]; then
			nh_config="nethunter_gingko_defconfig"
			ak3_branch="gingko"
			zipname="gingko-nethunter-$(date '+%Y%m%d-%H%M').zip"
			tarball="gingko-modules-$(date '+%Y%m%d-%H%M').tar"
			dtbo="arch/arm64/boot/dts/xiaomi/ginkgo-trinket-overlay.dtbo"

		else
			printf "${red}Unrecognized option for -m,${clear_color}\nPlease type either ${green}laurel${clear_color} or ${green}gingko${clear_color}\n"
			exit 1
		fi	
		config_command="$nh_config"
		;;		
	c)
		#still copy the defconfig to .config before running nconfig
		cp $topdir/arch/arm64/configs/$nh_config $topdir/.config
		config_command="nconfig"
   		;;
   	h)
   		usage
   		;;
	b)
		make_prefix="ionice -c 3 chrt --idle 0 nice -n19"
		;;
   	\?)
   		printf "${red}Unrecognized option: ${clear_color}-$OPTARG\n"
   		usage
   		;;
	esac
done
shift "$(( OPTIND - 1 ))"
if [ -z "$model" ]; then
	printf "${red}Missing -m flag\n${clear_color}"
	usage
	exit 1
fi
#check for sane build environment
#define confirm/deny functions
confirm() {
	printf "${green}yes${clear_color}\n"
}
deny() {
	printf "${red}no${clear_color}\n"
}
printf "Checking that operating system is ${yellow}Linux${clear_color}... "
if [ "$(uname -s)" == "Linux" ]; then
	confirm
else
	deny
	printf "Building ${red}not supported${clear_color} on operating systems ${red}other than Linux${clear_color}. Quitting\n"
	exit 1
fi
printf "Checking that architecture is ${yellow}x86_64 ${clear_color}... "
if [ "$(uname -m)" == "x86_64" ]; then
	confirm
else
	deny
	printf "Building ${red}not supported${clear_color} on architectures ${red}other than x86_64${clear_color}. Quitting\n"
	exit 1
fi
check_installation() {
printf "Checking for ${yellow}$program${clear_color}... "
if command -v $program >/dev/null 2>&1; then
	confirm
else
	deny
	printf "Please install ${red}$program${clear_color} and run this script again\n"
	exit 1
fi
}
programs="git curl grep bash bison flex python3 gzip tar xz make gcc perl awk swig pkg-config zstd dtc"
for p in $programs; do
	program=$p
	check_installation
done
#pull submodules
printf "${green}Updating kernel source${clear_color}\n"
git pull
printf "${green}Updating submodules${clear_color}\n"
git submodule init
git submodule update --remote
if [ ! -d "$tc_dir" ]; then
	printf "${red}Toolchain${clear_color} directory not found! Downloading to ${yellow}$tc_dir${clear_color}... \n"
	mkdir -p $tc_dir
	cd $tc_dir
	curl -fsSL $tc_url | tar --zstd -xf -
	if [ ! -e "$tc_dir/bin/clang-19" ]; then
		printf "${red}Something went wrong${clear_color}\n"
		exit 1
	else
		printf "${green}downloaded${clear_color}\n"
	fi
else
	if [ ! -e "$tc_dir/bin/clang-19" ]; then
		printf "${yellow}$tc_dir/bin${clear_color} does not contain expected files...\n"
		printf "If you want to continue anyway, perhaps using a different version of clang, type \'continue\' now: "
		read continue_anyway
       		if [ "$continue_anyway" == "continue" ]; then
	 		printf "\nContinuing...${clear_color}\n"
		else
			printf "\n${red}Build cancelled${clear_color}\n"
			exit 1
		fi
	fi		
fi
#check for mkdtimg and download if not found
if ! command -v mkdtimg >/dev/null 2&>1; then
	if [ ! -e "$tc_dir/bin/mkdtimg" ]; then
		printf "${red}mkdtimg${clear_color} not found in"
	       	printf ' $PATH ' 
		printf "or toolchain bin/ directory - downloading... "
		curl -o $tc_dir/bin/mkdtimg -fsSL $mkdtimg_url && printf "${green}downloaded${clear_color}\n"
		chmod +x $tc_dir/bin/mkdtimg
	else
		printf "${green}mkdtimg${clear_color} found in toolchain directory\n"
	fi
else
	printf "${green}mkdtimg${clear_color} found in user's PATH\n"
fi
#using wrapper around /usr/bin/dtc to pass options to it
if [ ! -e "$tc_dir/bin/dtc" ]; then
	cp $topdir/dtc $tc_dir/bin/dtc
	chmod +x $tc_dir/bin/dtc
fi
#get anykernel3 branch
if [ ! -d "$ak3_dir" ]; then
	printf "Cloning ${green}AnyKernel3${clear_color} repo...\n"
	git clone https://github.com/akabul0us/AnyKernel3 -b $ak3_branch $ak3_dir
else
	printf "${green}AnyKernel3${clear_color} repo already in source tree\n"
fi
export PATH="$tc_dir/bin:$PATH"
cd $topdir
#see if we want to clean up artifacts from a previous build
printf "Checking for ${yellow}build artifacts${clear_color}...\n"
if (find . -name "*.o" > /dev/null); then
        printf "${yellow}Build artifacts${clear_color} found -- clean before continuing? (y/n) "
        read make_clean
        if [ "$make_clean" == "y" ]; then
		printf "${green}Cleaning${clear_color}...\n"
                make ${make_options} clean
        else
                printf "\n${yellow}Continuing${clear_color} without cleaning\n"
        fi
fi
printf "Running ${green}configuration${clear_color}...\n"
${make_prefix} make ${make_options} -j$(nproc --all) $config_command
printf "\nStarting ${green}compilation${clear_color}...\n"
${make_prefix} make ${make_options} -j$(nproc --all)
kernel="arch/arm64/boot/Image.gz-dtb"
#some builds won't have the concatenated image, so allow the script to find the other option
kernel_2="arch/arm64/boot/Image.gz"
if [ ! -f "$kernel" ]; then
	if [ -f "$kernel_2" ]; then
		kernel="$kernel_2"
	else
		printf "${red}Build failed${clear_color}\n"
		exit 1
	fi
else
	cd $ak3_dir
	printf "Copying compiled ${green}kernel image${clear_color} into $ak3_dir\n"
	cp $topdir/$kernel .
	if [ -f "$topdir/$dtbo" ]; then
		printf "Packing ${green}dtbo.img${clear_color}...\n"
		mkdtimg create dtbo.img $topdir/$dtbo
	fi
	zip -r9 "$topdir/$zipname" * -x .git README.md *placeholder && printf "Kernel zip ${green}$zipname${clear_color} created\n"
fi
#pack modules tarball
moduledir="modules-$(date '+%Y%m%d-%H%M')"
cd $topdir
printf "Looking for compiled ${yellow}modules${clear_color}... "
if (find . -name *.ko > /dev/null); then
	printf "${green}found${clear_color} - packing tarball\n"
	module_paths="$(find . -name *.ko)"
	mkdir -p $topdir/$moduledir
	for m in $module_paths; do
		cp $m $moduledir
	done
	cd $moduledir
	tar cf ../$tarball *
	gzip -9 ../$tarball
	rm -rf $topdir/$moduledir
	printf "Modules tarball ${green}$topdir/$tarball.gz${clear_color} created\n"
else
	printf "None found\n"
fi
printf "\nCompleted in${green} $((SECONDS / 60)) minute(s) ${clear_color} and${green} $((SECONDS % 60)) second(s)${clear_color}!\n"
