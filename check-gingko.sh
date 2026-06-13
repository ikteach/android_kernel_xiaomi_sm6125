#!/usr/bin/env bash
configs="CONFIG_MACH_XIAOMI_C3J  CONFIG_BACKLIGHT_KTD3136  CONFIG_INPUT_FINGERPRINT CONFIG_FINGERPRINT_FPC1020 CONFIG_FINGERPRINT_GF3208  CONFIG_NFC_NQ  CONFIG_TOUCHSCREEN_NT36xxx_HOSTDL_SPI_C3J CONFIG_TOUCHSCREEN_FTS_C3J CONFIG_TOUCHSCREEN_XIAOMI_C3J"
for c in $configs; do
	if ! grep -E "^$c=y" .config; then
		lineno="$(grep -n $c .config | cut -d : -f 1 | head -n 1)"
		echo "Setting $c=y on line $lineno"
		sed -i "${lineno}s/.*/$c=y/g" .config
	else
		echo "$c set correctly"
	fi
done
