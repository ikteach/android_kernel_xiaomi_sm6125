#!/usr/bin/env bash
nord="$HOME/android_kernel_oneplus_avicii"
topdir="$(pwd)"
if [ ! -d "$nord" ]; then
	echo "Cloning repo with qcacld-3.0 patches..."
	git clone --depth=1 https://github.com/kimocoder/android_kernel_oneplus_avicii $nord
else
	echo "Updating..."
	cd $nord && git pull && cd $topdir
fi
files="drivers/staging/qca-wifi-host-cmn/dp/wifi3.0/dp_internal.h drivers/staging/qca-wifi-host-cmn/qdf/inc/qdf_trace.h drivers/staging/qca-wifi-host-cmn/qdf/inc/qdf_types.h drivers/staging/qca-wifi-host-cmn/qdf/linux/src/i_qdf_defer.h drivers/staging/qca-wifi-host-cmn/qdf/linux/src/i_qdf_hrtimer.h drivers/staging/qca-wifi-host-cmn/qdf/linux/src/i_qdf_nbuf.h drivers/staging/qca-wifi-host-cmn/qdf/linux/src/i_qdf_str.h drivers/staging/qca-wifi-host-cmn/qdf/linux/src/i_qdf_time.h drivers/staging/qca-wifi-host-cmn/qdf/linux/src/i_qdf_timer.h drivers/staging/qcacld-3.0/Kbuild drivers/staging/qcacld-3.0/components/ipa/core/src/wlan_ipa_core.c drivers/staging/qcacld-3.0/configs/default_defconfig drivers/staging/qcacld-3.0/core/dp/txrx/ol_txrx_internal.h drivers/staging/qcacld-3.0/core/dp/txrx/ol_txrx_ipa.c drivers/staging/qcacld-3.0/core/hdd/inc/wlan_hdd_bcn_recv.h drivers/staging/qcacld-3.0/core/hdd/inc/wlan_hdd_frame_inject.h drivers/staging/qcacld-3.0/core/hdd/inc/wlan_hdd_frame_inject_debug.h drivers/staging/qcacld-3.0/core/hdd/inc/wlan_hdd_frame_inject_integration.h drivers/staging/qcacld-3.0/core/hdd/inc/wlan_hdd_frame_inject_security_test.h drivers/staging/qcacld-3.0/core/hdd/inc/wlan_hdd_frame_inject_test.h drivers/staging/qcacld-3.0/core/hdd/inc/wlan_hdd_frame_validate.h drivers/staging/qcacld-3.0/core/hdd/inc/wlan_hdd_frame_validate_test.h drivers/staging/qcacld-3.0/core/hdd/inc/wlan_hdd_inject_security.h drivers/staging/qcacld-3.0/core/hdd/inc/wlan_hdd_main.h drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_assoc.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_cfg80211.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_cfg80211.h drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_debugfs_csr.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_debugfs_offload.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_ext_scan.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_frame_inject.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_frame_inject_comprehensive_test.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_frame_inject_debug.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_frame_inject_integration.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_frame_inject_security_test.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_frame_inject_test.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_frame_validate.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_frame_validate_test.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_hostapd.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_inject_security.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_ioctl.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_lpass.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_main.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_oemdata.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_rx_monitor.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_rx_monitor.h drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_sysfs.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_tx_rx.c drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_wext.c drivers/staging/qcacld-3.0/core/mac/src/include/parser_api.h drivers/staging/qcacld-3.0/core/mac/src/include/utils_api.h drivers/staging/qcacld-3.0/core/mac/src/sys/legacy/src/platform/src/sys_wrapper.c drivers/staging/qcacld-3.0/core/mac/src/sys/legacy/src/utils/inc/utils_parser.h drivers/staging/qcacld-3.0/core/pld/src/pld_common.c drivers/staging/qcacld-3.0/core/pld/src/pld_ipci.c drivers/staging/qcacld-3.0/core/pld/src/pld_pcie.c drivers/staging/qcacld-3.0/core/pld/src/pld_pcie_fw_sim.c drivers/staging/qcacld-3.0/core/pld/src/pld_snoc.c drivers/staging/qcacld-3.0/core/wma/inc/wma_frame_inject.h drivers/staging/qcacld-3.0/core/wma/src/wma_frame_inject.c drivers/staging/qcacld-3.0/core/wma/src/wma_main.c drivers/staging/qcacld-3.0/wlan.mod"
for f in $files; do
	if [ -f "$topdir/$f" ]; then
		read -p "$topdir/$f already exists: show diff? (Y/n)" yorn
		case $yorn in
			[Yy*])
				diff --color "$topdir/$f" "$nord/$f"
				;;
			[Nn])
				echo "I, too, like to live dangerously"
				;;
		esac
		unset yorn
		read -p "Copy $f? (Y/n)" copyfile
		case $copyfile in
			[Yy*])
				echo "Copying $f from $nord to $topdir"
				cp $nord/$f $topdir/$f
				;;
			[Nn])
				echo "$f not copied"
				;;
		esac
	else
		echo "$f is a new file - copying into $topdir"
		cp $nord/$f $topdir/$f
	fi
done
