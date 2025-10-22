#!/usr/bin/env bash

#define colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
clear_color='\033[0m'

#help output
usage() {
	printf "${green}Usage: ${clear_color}./build.sh -m [laurel|gingko] [-c] [-h] [-b]\n"
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
ak3_dir="$topdir/AnyKernel3"

export KBUILD_BUILD_USER="$(whoami)"
export KBUILD_BUILD_HOST="$(hostname)"

make_options='ARCH=arm64 CC=clang AS=llvm-as CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 DTC_EXT=/usr/bin/dtc'
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
		elif [ "$model" == "gingko" ]; then
			nh_config="nethunter_gingko_defconfig"
			ak3_branch="gingko"
			zipname="gingko-nethunter-$(date '+%Y%m%d-%H%M').zip"
			tarball="gingko-modules-$(date '+%Y%m%d-%H%M').tar"
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
	printf "${red}Missing -m option\n${clear_color}"
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
printf "${yellow}Checking that operating system is Linux... ${clear_color}"
if [ "$(uname -s)" == "Linux" ]; then
	confirm
else
	deny
	printf "${red}Building not supported on operating systems other than Linux. Quitting${clear_color}\n"
	exit 1
fi
printf "${yellow}Checking that architecture is x86_64... ${clear_color}"
if [ "$(uname -m)" == "x86_64" ]; then
	confirm
else
	deny
	printf "${red}Building not supported on architectures other than x86_64. Quitting${clear_color}\n"
	exit 1
fi
check_installation() {
printf "${yellow}Checking for $program... "
if command -v $program >/dev/null 2>&1; then
	confirm
else
	deny
	printf "${red}Please install $program and run this script again${clear_color}\n"
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
git pull --recurse-submodules
#for some reason this^ does not always work
#until i figure out why, this next bit is designed to check if it did, and if not, add the submodules one by one
if [ ! -f "$topdir/drivers/net/wireless/mediatek/mt76/mt76x2_core.c" ]; then
	printf "${red}Something has gone wrong with submodules${clear_color}\n"
	printf "${yellow}Adding one by one...${clear_color}\n"
	git submodule add --force https://github.com/aircrack-ng/rtl8188eus drivers/net/wireless/realtek/rtl8188eus
	git submodule add --force https://github.com/akabul0us/mt76 drivers/net/wireless/mediatek/mt76
	git submodule add --force https://github.com/akabul0us/rtl88x2bu drivers/net/wireless/realtek/rtl88x2bu
	git submodule add --force https://github.com/akabul0us/rtl8812au drivers/net/wireless/realtek/rtl8812au
	git submodule add --force https://github.com/akabul0us/rtl8188fu drivers/net/wireless/realtek/rtl8188fu
	git submodule add --force https://github.com/cyberknight777/android_kernel_docker android_kernel_docker
	git submodule add --force https://github.com/cyberknight777/android_kernel_nethunter android_kernel_nethunter
	#git submodule add https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder kali-nethunter-kernel-builder
fi
if [ ! -d "$tc_dir" ]; then
	printf "${red}Toolchain directory not found! ${yellow}Downloading to $tc_dir...${clear_color}\n"
	mkdir -p $tc_dir
	cd $tc_dir
	curl -fsSL $tc_url | tar --zstd -xvf -
	if [ ! -e $tc_dir/bin/clang-19 ]; then
		printf "${red}Something went wrong${clear_color}\n"
		exit 1
	else
		printf "${green}Success! ${clear_color}\n"
	fi
else
	if [ ! -e $tc_dir/bin/clang-19 ]; then
		printf "${yellow}$tc_dir/bin does not contain expected files...\n"
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
#get anykernel3 branch
if [ ! -d "$ak3_dir" ]; then
	printf "${green}Cloning AnyKernel3 repo...${clear_color}\n"
	git clone https://github.com/akabul0us/AnyKernel3 -b $ak3_branch $ak3_dir
else
	printf "${yellow}AnyKernel3 repo already in source tree${clear_color}\n"
fi
export PATH="$tc_dir/bin:$PATH"
cd $topdir
#see if we want to clean up artifacts from a previous build
printf "${yellow}Checking for build artifacts...\n${clear_color}"
find . -name "*.o" > /dev/null
found="$?"
if [ "$found" -eq 0 ]; then
        printf "${yellow}Build artifacts found -- clean before continuing?${clear_color} (y/n)\n"
        read make_clean
        if [ "$make_clean" == "y" ]; then
                make ${make_options} clean
        else
                printf "${yellow}Continuing without cleaning${clear_color}\n"
        fi
fi
printf "${green}Running configuration...${clear_color}\n"
make ${make_prefix} ${make_options} -j$(nproc --all) $config_command
printf "\n${green}Starting compilation... ${clear_color}\n"
make ${make_prefix} ${make_options} -j$(nproc --all)
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
	printf "${green}\nKernel compiled succesfully! ${clear_color}Zipping up...\n"
	cd $ak3_dir
	cp $topdir/$kernel .
	zip -r9 "../$zipname" * -x .git README.md *placeholder
	printf "\nCompleted in${green} $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)! ${clear_color}\n"
	echo "Zip: $zipname"
fi
#pack modules tarball
cd $topdir
printf "${yellow}Looking for compiled modules...${clear_color}\n"
module_paths="$(find . -name *.ko | sed ':a;N;$!ba;s/\n/ /g')"
if [ -z "$module_paths" ]; then
	printf "${yellow}None found\n${clear_color}"
else
	if [ ! -d "$topdir/modules" ]; then
		mkdir -p $topdir/modules
	fi
	cp $module_paths $topdir/modules/
	cd $topdir/modules
	tar cvf ../$tarball *
	gzip -9 ../$tarball
	printf "${green}Modules tarball $topdir/$tarball.gz created${clear_color}\n"
fi
