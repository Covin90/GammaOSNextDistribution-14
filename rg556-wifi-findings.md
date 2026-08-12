# RG556 WiFi — build comparison

Structure: one `##` section per build. Append GammaOS results under their own
heading using the same Step 0–4b layout so the two are directly comparable.

---

## Baseline: Anbernic stock (UNISOC/ums9620_2h10_native/ums9620_2h10:13/TP1A.220624.014/dell07061811:user/release-keys)

Captured 2026-08-11. Device time is UTC+2; all log timestamps below are device-local.
WiFi was working normally throughout — this is a reference capture, not a fault reproduction.

**Collection constraints (affect what could be measured):**

- `adb root` refused: `adbd cannot run as root in production builds`. Shell is uid 2000.
- **`dmesg` is unreadable.** SELinux denies it outright:
  ```
  avc: denied { syslog_read } for scontext=u:r:shell:s0 tcontext=u:r:kernel:s0 tclass=system permissive=0
  avc: denied { read } for name="dmesg_restrict" ... tclass=file permissive=0
  ```
  Every `dmesg` line in the capture plan returned `dmesg: klogctl: Permission denied`.
  No kernel-side data was collected, on any step. The same restriction will apply to
  a GammaOS user build unless it ships permissive adbd or is rooted.
- `/vendor/bin/hw/wpa_supplicant` is unreadable to shell (`Permission denied`), so Step 2
  was answered from the same binary extracted offline from a vendor image — see Step 2.
- Device was **charging over USB** for the whole capture, so Doze never engaged
  (`Idling history: normal: -3m55s265ms (charging)`). Screen-off suspend optimization is
  driven by WifiManager screen state, not Doze, so it still fired — but no Doze data exists here.

### Step 0 — build identification

```
ro.build.fingerprint      UNISOC/ums9620_2h10_native/ums9620_2h10:13/TP1A.220624.014/dell07061811:user/release-keys
ro.build.version.sdk      33
ro.build.version.release  13
ro.build.version.incremental  eng.dell.20260706.181359
ro.build.date             Mon Jul  6 18:11:06 CST 2026
ro.board.platform         ums9620
ro.vndk.version           33
ro.boot.product.hardware.sku  wifionly
```

Reported by the owner as Anbernic **V1.16**. Anbernic's download page
(https://win.anbernic.com/download/566.html) currently lists V1.12, V1.14, V1.15, V1.16.

### Step 1 — suspend optimizations

```
settings get global wifi_suspend_optimizations_enabled
null
```

Unset — the framework default (enabled) applies. Confirmed by dumpsys:

```
mSuspendOptimizationsEnabled true
mSuspendOptNeedsDisabled 0
```

Relevant neighbours:

```
wifi_sleep_policy                       = 2
wifi_scan_always_enabled                = 0
low_power                               = 0
adaptive_connectivity_enabled           = null
device_idle_constants                   = null
```

`dumpsys wifi` state-machine records showing the command tracking screen state:

```
rec[2]:  time=08-11 21:27:15.775 processed=ConnectableState org=DisconnectedState  what=CMD_SET_SUSPEND_OPT_ENABLED screen=on  0 0
rec[25]: time=08-11 21:27:27.633 processed=ConnectableState org=L3ConnectedState   what=CMD_SET_SUSPEND_OPT_ENABLED screen=off 1 1
rec[32]: time=08-11 21:29:44.434 processed=ConnectableState org=L3ConnectedState   what=CMD_SET_SUSPEND_OPT_ENABLED screen=on  0 0
rec[35]: time=08-11 21:31:33.913 processed=ConnectableState org=L3ConnectedState   what=CMD_SET_SUSPEND_OPT_ENABLED screen=off 1 1
```

Connection quality at capture time, for reference:

```
"ASUS_38_5G" 4c:ed:fb:b6:bb:3c rssi=-54 f=5280 sc=60 link=234 tx=1.0, 0.0, 0.0 rx=0.0 bcn=29 score=60
networkType=TYPE_WPA3, mAuthentication=2, mRouterTechnology=5, signalStrength=-53
mMaxSupportedTxLinkSpeedMbps=433, mMaxSupportedRxLinkSpeedMbps=433, useRandomizedMac=true
Wi-Fi standard: 5, Link speed: 433Mbps, Rx Link speed: 390Mbps, Frequency: 5280MHz
```

Association was clean and first-try:

```
ASSOCIATING -> ASSOCIATED -> FOUR_WAY_HANDSHAKE -> GROUP_HANDSHAKE -> COMPLETED
CMD_IPV4_PROVISIONING_SUCCESS ... IP address 192.168.1.52/24 Gateway 192.168.1.1
durationMillis=3534, connectionResult=1, level2FailureCode=NONE, numConsecutiveConnectionFailure=0
```

### Step 2 — wpa_supplicant provenance

On-device binary unreadable (SELinux). Analysed instead from
`/vendor/bin/hw/wpa_supplicant` extracted out of the **GammaOS pac's** `vendor_a.img`
(`rg556work/superparts/vendor_a.img`). **This is GammaOS's vendor copy, not the running
stock 1.16 copy** — they are believed equivalent but that was not verified byte-for-byte.

```
sha256  1b93e02d9f818c114daef371ddbf7cb23491c89c0f410455005ac908af456d24
size    3100320
ELF 64-bit LSB pie executable, ARM aarch64, for Android 33, stripped
```

Grep `sprd|unisoc|SETSUSPENDMODE|v2\.[0-9]+` over 21,102 extracted strings — full output, 6 hits:

```
WPS: Invalid PKCS#5 v2.0 pad value
SETSUSPENDMODE
WPS: Invalid PKCS#5 v2.0 pad string
wpa_supplicant v2.11-devel-13
SETSUSPENDMODE 1
SETSUSPENDMODE 0
```

**Zero `sprd` or `unisoc` strings.** Vendor-command strings present are the standard
AOSP `wpa_supplicant_8` set:

```
SETSUSPENDMODE
SETBAND
DRIVER 
P2PMACADDR
%s: failed to issue private command P2PMACADDR %02x:%02x:%02x:%02x:%02x:%02x
nl80211: driver param='%s'
nl80211: Driver setband function failed: %s
Previous country code %s, new country code %s
```

The binary is stripped, so source-level patches cannot be excluded — but there is no
Unisoc branding and no vendor-specific private command beyond the AOSP baseline.

### Step 3 — HAL interface

```
$ dumpsys -l | grep -i wifi
  android.hardware.wifi.supplicant.ISupplicant/default
  uni_wifi
  wifi
  wifinl80211
  wifip2p
  wifiscanner
```

```
$ lshal | grep -i wifi
Warning: Skipping "android.hardware.wifi@1.0::IWifi/default": cannot be fetched from service manager (null)
  ... identical warnings for @1.1 through @1.6 ...
DM    ? android.hardware.wifi@1.0::IWifi/default        N/A  N/A
DM    ? android.hardware.wifi@1.1::IWifi/default        N/A  N/A
DM    ? android.hardware.wifi@1.2::IWifi/default        N/A  N/A
DM,FC ? android.hardware.wifi@1.3::IWifi/default        N/A  N/A
DM,FC ? android.hardware.wifi@1.4::IWifi/default        N/A  N/A
DM,FC ? android.hardware.wifi@1.5::IWifi/default        N/A  N/A
DM,FC ? android.hardware.wifi@1.6::IWifi/default        N/A  N/A
DC,FM ? android.system.wifi.keystore@1.0::IKeystore/default  N/A  N/A
```

(The "cannot be fetched" warnings are a shell-permission artifact, not a missing service —
the HAL process is running, see below.)

```
$ ps -A | grep -iE "wpa|wifi|hostapd"
wifi   649   1  10978500 10216  S  android.hardware.wifi@1.0-service
wifi   825   1  10852776  7120  S  wificond
root   948   2         0     0  S  [wifi_driver_chr]
wifi  1333   1  10899808 10724  S  wpa_supplicant
```

```
$ getprop | grep -iE "wifi|wlan|sprd"
[init.svc.sprd_networkcontrol]: [running]
[init.svc.wificond]: [running]
[ro.boot.product.hardware.sku]: [wifionly]
[ro.sprd.displayenhance]: [true]
[ro.sprd.nightdisplay.enhance]: [true]
[ro.sprd.superresolution]: [1]
[ro.wifi.channels]: []
[sys.wifitracing.started]: [1]
```

Loaded WLAN kernel modules (`lsmod`, WCN-relevant subset):

```
sprd_wlan_combo      1101824  0
wcn_bsp               733184  4 gnss_common_ctl_all,sprd_fm,sprdbt_tty,sprd_wlan_combo
pcie_sprd              24576  1 wcn_bsp
pcie_sprd_misc         20480  2 wcn_bsp,pcie_sprd
sipa_core             270336  6 sprd_pamu3,sprd_wlan_combo,sfp_core,sipa_usb,sipa_eth,sipa_dele
sipc_core             192512  17 ...,sprd_wlan_combo,wcn_bsp,...
```

**There is no `sprdwl_ng` module loaded.** The WLAN driver on this platform is
`sprd_wlan_combo` on top of `wcn_bsp`, over PCIe.

### Step 4 — screen-off / screen-on transition capture

`dmesg`: unavailable (see constraints). logcat only.

First capture window was mistimed (buffer cleared after the screen-off transition), so a
second window was run: cleared at device time **21:38:26**, collected **21:44:11**.
Complete, unfiltered list of every `wpa_supplicant` line in that window:

```
08-11 21:38:41.497  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:38:41.503  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 0' success
08-11 21:38:51.782  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:38:51.782  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 1' success
08-11 21:39:03.985  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:39:03.985  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 0' success
08-11 21:39:09.920  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:39:09.925  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 1' success
08-11 21:40:09.962  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:40:09.965  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 0' success
08-11 21:40:20.235  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:40:20.240  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 1' success
08-11 21:40:21.661  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:40:21.667  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 0' success
08-11 21:40:46.398  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:40:46.404  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 1' success
08-11 21:41:16.576  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:41:16.581  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 0' success
08-11 21:41:26.850  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:41:26.856  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 1' success
08-11 21:41:28.052  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:41:28.052  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 0' success
08-11 21:43:29.247  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:43:29.252  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 1' success
```

12 `SETSUSPENDMODE` invocations in 5m45s. Every one returns `success`. No other
`driver_cmd` of any kind was issued — `SETSUSPENDMODE` is the only private command
in the entire window.

`WifiVendorHal` and `SupplicantStaIface` produced **no output at all** — those tags are
not logged at default verbosity on this user build.

Earlier window, same command on wake (kept for the tag format):

```
08-11 21:37:16.524  1333  1333 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
08-11 21:37:16.530  1333  1333 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 0' success
```

Note the tight pairs at **21:40:20.240 → 21:40:21.667 (1.4 s)** and
**21:41:26.856 → 21:41:28.052 (1.2 s)**: suspend mode is entered and immediately left.
The device's screen timeout is short, so the command flaps rapidly. Stock absorbs this
without any connection disturbance.

### Step 4b — screen-on idle baseline

`dmesg`: unavailable.

The screen-on idle period is bounded by the two commands either side of it:

```
08-11 21:41:28.052  driver cmd 'SETSUSPENDMODE 0' success   <- screen on
        ... 121 seconds, no wpa_supplicant output whatsoever ...
08-11 21:43:29.252  driver cmd 'SETSUSPENDMODE 1' success   <- screen timed out
```

**During 121 seconds of screen-on idle, zero driver commands were issued.** No
`SETSUSPENDMODE`, no other `driver_cmd`, no supplicant state change, no reassociation.

Doze/idle state (device charging, so idling never advanced):

```
Idling history:
     normal: -3m55s265ms (charging)
device_idle_constants = null   (all defaults)
light_after_inactive_to=+4m0s0ms   light_idle_to=+5m0s0ms   light_idle_factor=2.0
inactive_to=+30m0s0ms   idle_after_inactive_to=+30m0s0ms   idle_to=+1h0m0s0ms
quick_doze_delay_to=+1m0s0ms   wait_for_unlock=true
```

### Interpretation

**H1 — suspend optimizations.** Stock **does** fire `SETSUSPENDMODE`, and it fires
**strictly on screen-state transitions**: `1` on screen off, `0` on screen on, and nothing
in between. 121 seconds of screen-on idle produced no driver command at all. So the
suspend path is exercised heavily on stock — 12 times in under six minutes, twice with
under 1.5 s between enter and exit — and never misbehaves. `wifi_suspend_optimizations_enabled`
is `null` (default-on) and `mSuspendOptimizationsEnabled` is `true`.

Two consequences for the GammaOS comparison. First, if GammaOS also logs
`driver cmd 'SETSUSPENDMODE 1' success`, then the *call* is not the difference and the
divergence is below that line — in how `sprd_wlan_combo` handles it, or in what else the
Android 14 framework does around it. Second, because the upstream report says the fault
also occurs **screen-on**, and stock issues *nothing* during screen-on idle, any driver
command appearing in a GammaOS screen-on idle window is by itself anomalous. That makes
Step 4b the more discriminating of the two windows, despite producing no stock output —
the empty 121 seconds *is* the baseline.

**H2 — wpa_supplicant provenance.** `wpa_supplicant v2.11-devel-13`, with **no `sprd` or
`unisoc` strings** and no private commands beyond the AOSP set. This reads as a stock
AOSP `wpa_supplicant_8` build, not a Unisoc-patched one — `SETSUSPENDMODE` is itself part
of AOSP's `driver_cmd` surface, not a vendor addition. Caveats: the binary is stripped, and
the copy analysed came from GammaOS's `vendor_a.img` rather than the running stock 1.16
vendor, because SELinux blocked reading the live one. Diffing this against stock's own
`wpa_supplicant` would close that gap — the 1.11 pac
(`~/Downloads/ums9620_2h10_rg_556_1.11.zip`, 7.46 GB inner `.pac`) can supply one, though
1.11 is not the running 1.16 either.

**H3 — HAL interface.** Mixed, and this is the most likely place for an Android 14 problem.
The **supplicant is AIDL** (`android.hardware.wifi.supplicant.ISupplicant/default`), while the
**vendor WiFi HAL is HIDL** — the running process is `android.hardware.wifi@1.0-service`
and the manifest declares `android.hardware.wifi@1.0` through `@1.6`. No AIDL `IWifi`
is declared. No shim was observed, but `lshal` could not fetch interface details without
root, so a shim cannot be ruled out from this capture. A Unisoc-specific system service
`uni_wifi` is also registered, alongside `sprd_networkcontrol`.

That HIDL-only vendor HAL is worth attention: AOSP began removing HIDL WiFi HAL support
in favour of AIDL, and an Android 14 GSI talking to a HIDL `@1.6` vendor HAL is exactly
the kind of seam where behaviour diverges without any blob changing. This is a hypothesis
generated by the baseline, not something measured here.

**Correction to a premise.** The driver is **`sprd_wlan_combo`** (1,101,824 bytes) over
`wcn_bsp`, not `sprdwl_ng` — no `sprdwl_ng` module is loaded. Any search for patched
drivers or upstream fixes should target `sprd_wlan_combo` / `wcn_bsp`.

**Not measured.** Nothing kernel-side: `dmesg` was denied by SELinux on this user build,
so there is no driver-level evidence in this baseline at all, and none of the
`sprdwl`/`wlan` kernel-log greps in the plan could run. Doze behaviour was also not
captured, since USB charging suppressed it.

### Reproducing this on GammaOS

Run identically, with the same charging state and a matched screen timeout:

```bash
adb logcat -c
# screen off 30s, screen on, then 120s awake and idle
adb logcat -d -b all | grep -iE "wpa_supplicant"
adb logcat -d -b all | grep -iE "SETSUSPENDMODE|driver cmd"
adb shell dumpsys wifi | grep -iE "suspend|power save|screen"
adb shell settings get global wifi_suspend_optimizations_enabled
adb shell lsmod | grep -iE "sprd_wlan|wcn_bsp"
adb shell dumpsys -l | grep -i wifi
```

If GammaOS is rooted or ships permissive `adbd`, also capture what stock could not:

```bash
adb shell dmesg | grep -iE "sprd_wlan|wcn|wlan|suspend"
```

Raw per-step output is in `rg556work/wifi-baseline/`.

---

## Appendix A: vendor partition diff — stock 1.11 vs GammaOS Next v1.2

Added after the baseline capture, to close the H2 caveat (the wpa_supplicant analysed was
GammaOS's copy, not stock's). It closed that gap and turned up something larger.

Method: `ums9620_2h10_rg_556_1.11.zip` -> inner 7.46 GB `.pac` -> `Super` extracted by
offset (`pacpick.py`) -> `lpunpack` -> partitions compared **file-by-file** (the two use
different filesystems, so byte-comparing images is meaningless).

### A.1 Filesystem types

| partition | stock 1.11 | GammaOS v1.2 | live 1.16 (`/proc/mounts`) |
|---|---|---|---|
| `vendor_a` | EROFS `B1BA2634…FCE` | **ext4** `d034669c…4d2` | erofs |
| `vendor_dlkm_a` | EROFS `8C1C4AE2…A37D` | EROFS `8C1C4AE2…A37D` | erofs |
| `odm_a` | — | EROFS `EA351207…38FF` | erofs |

GammaOS **rebuilt vendor as ext4**; `vendor_dlkm` and `odm` were left as shipped.

### A.2 Both vendors are the same Anbernic build

```
ro.vendor.build.fingerprint=UNISOC/ums9620_2h10_native/ums9620_2h10:13/TP1A.220624.014/dell02192007:user/release-keys
ro.vendor.build.version.incremental=eng.dell.20240219.201058
ro.vendor.build.date=Mon Feb 19 20:07:52 CST 2024
```

Identical in stock 1.11 and GammaOS. So differences are GammaOS's doing, not Anbernic drift.

### A.3 `wpa_supplicant` — identical

```
stock 1.11 (erofs vendor)  1b93e02d9f818c114daef371ddbf7cb23491c89c0f410455005ac908af456d24  3100320
GammaOS v1.2 (ext4 vendor) 1b93e02d9f818c114daef371ddbf7cb23491c89c0f410455005ac908af456d24  3100320
=> BYTE-IDENTICAL
```

**H2 caveat closed.** Same binary in both. (Still 1.11, not the running 1.16.)

### A.4 `vendor_dlkm` — identical, driver included

All **140 files byte-identical**, 129 `.ko` each:

```
d34b692e25ed38b2eb316d8f40a5a016524cff9b14f8ed809a061418f1124f1c  ./lib/modules/sprd_wlan_combo.ko
3f0a886af6e64de38225c2313700e2e12b16b7cc5c67caf6db41f6c711025b95  ./lib/modules/wcn_bsp.ko
```

Confirms the premise: **the WLAN driver is bit-identical between the two builds.**

### A.5 The 323 changed vendor files are almost all noise

Of 311 changed files that kept their exact size, **309 differ in <=64 bytes** — the ELF
`.note.gnu.build-id` only. Recompiled, not modified. Example
(`./lib/android.hardware.boot@1.0.so`, 67136 bytes): exactly **16 bytes differ**, at
offsets 413–428.

Two files differ far more: `lib64/egl/libGLES_mali.so` and `lib/libGLES_mali.so`
(~34.3 MB of 43.7 MB differ; only 21.5% of bytes equal). **This is not a driver update.**
All three sources report the identical Mali build:

```
stock 1.11 blob    r40p0-01eac0.b0251c048237dcd59e6be15fba11a31a
GammaOS v1.2 blob  r40p0-01eac0.b0251c048237dcd59e6be15fba11a31a
live 1.16 device   GLES: ARM, Mali-G57, OpenGL ES 3.2 v1.r40p0-01eac0.b0251c048237dcd59e6be15fba11a31a
                   (adb shell dumpsys SurfaceFlinger)
```

The blobs are the same size and the same DDK release, but have different ELF BuildIDs
(`3db22a957a7c6d88` vs `637bc6ae84a87bee`) and an 8-byte layout shift near offset 144
(`6c1b7300` vs `641b7300`), which desynchronises byte-wise comparison for the rest of the
file and inflates the apparent difference. String content is 93.4% identical
(87,529 of ~93,750 unique strings common; the non-shared remainder is binary noise, not
symbols). So: **same GPU driver, relinked** — not a version change, and not WiFi-related.

`build.prop` changes are display rotation (`ORIENTATION_90`), `ro.sf.lcd_density=360`,
sensor orientations, and `persist.gammaos.*` / `persist.gammargb.*` keys.
**No WiFi-related property changed.**

Verified independently: `debugfs` reproduced `7z`'s hashes exactly for the sampled files,
so the ext4 extraction is sound.

Caveat on the file lists: `7z` materialises ext4 symlinks as empty regular files, while
`fsck.erofs` preserves them, so symlinks show up as spurious "added" entries. Example:
`lib64/hw/vulkan.ums9620.so` appeared to be GammaOS-only, but `debugfs` shows it is a
symlink in *both* (`Fast link dest: "../egl/libGLES_mali.so"` — Vulkan and GLES are the
same blob). Removals were verified directly and are unaffected: `/overlay` genuinely does
not exist in GammaOS's vendor.

### A.6 The finding — GammaOS's vendor has no `/overlay` directory

```
$ debugfs -R "stat /overlay" superparts/vendor_a.img
/overlay: File not found by ext2_lookup
```

Stock ships 27 files under `/vendor/overlay`; GammaOS ships none. Removed set includes:

```
./overlay/AospWifiOverlay_Marlin3/AospWifiOverlay_Marlin3.apk                 (12638 B)
./overlay/AospWifiOverlay_Marlin3_Mainline/AospWifiOverlay_Marlin3_Mainline.apk (12638 B)
./overlay/UniWifiOverlay_Marlin3/UniWifiOverlay_Marlin3.apk                    (8542 B)
./overlay/NetworkStackOverlay.apk / NetworkStackOverlayGsi.apk
./overlay/TetheringConfigOverlay_N6pro.apk / TetheringConfigOverlayGsi_N6pro.apk
./overlay/unisoc_overlay_frameworks_res.apk
./overlay/MultiuserOverlays.apk / AospBtOverlay/AospBtOverlay.apk
```

On the live stock device these are **enabled**:

```
$ adb shell cmd overlay list
com.android.wifi.resources      [x] com.android.wifi.resources.uni_marlin3
com.android.wifi.uniresources   [x] com.android.wifi.uniresources.marlin3
com.android.networkstack        [x] com.unisoc.android.overlay.wifionly
com.android.networkstack        [x] com.android.networkstack.overlay
com.android.networkstack.tethering [x] com.android.networkstack.tethering.overlay
```

`com.android.wifi.resources` is the WiFi framework's own resource package. GammaOS runs
with **AOSP defaults for every one of these keys.**

### A.7 What the removed WiFi overlay actually changes

`AospWifiOverlay_Marlin3.apk` (`com.android.wifi.resources.uni_marlin3`) values, vs AOSP
defaults read from `packages/modules/Wifi/service/ServiceWifiResources/res/values/config.xml`
in this tree:

| key | Unisoc (stock) | AOSP default (GammaOS) |
|---|---|---|
| `config_wifi_framework_enable_associated_network_selection` | **false** | **true** |
| `config_wifi_framework_wifi_score_entry_rssi_threshold_24GHz` | **-70** | **-80** |
| `config_wifi_framework_wifi_score_entry_rssi_threshold_5GHz` | **-66** | **-77** |
| `config_wifi_fast_bss_transition_enabled` (802.11r) | **true** | **false** |
| `config_wifi_background_scan_support` | **true** | **false** |
| `config_wifiSaeH2eSupported` | **true** | **false** |
| `config_wifi_connected_mac_randomization_supported` | true | (unchanged) |
| `config_wifi_framework_enable_sar_tx_power_limit` | true | — |
| `config_wifiHardwareSoftapMaxClientCount` | 10 | — |
| `config_wifiCharsetsForSsidTranslation` | `["all,GBK"]` | — |

`UniWifiOverlay_Marlin3.apk` sets `config_uniwifi_wlanPlusSupport` (Unisoc-private key).

**The first row is the strongest lead in this whole investigation.** Unisoc explicitly
disables associated network selection for this chipset; without the overlay, GammaOS
re-enables it, so the framework continuously re-evaluates and may switch away from a
working association. That runs regardless of screen state, which matches the upstream
report that the fault occurs both screen-off and screen-on — something the suspend-mode
hypothesis alone does not explain. The RSSI entry thresholds moving from -70/-66 to
-80/-77 compounds it: GammaOS will consider markedly weaker APs viable candidates.

This is a **hypothesis consistent with all measured evidence, not a demonstrated cause.**
It has not been tested on hardware.

### A.8 Correction — the GammaOS WiFi overlay is dead code

Earlier in this investigation I stated that
`device/gammaos/overlay/frameworks/opt/net/wifi/service/res/values/config.xml`
(setting `config_wifiSaeUpgradeEnabled=false`) applies to the RG556 build. **That was wrong.**

`frameworks/opt/net/wifi/MOVED.txt` in this tree:

```
- frameworks/opt/net/wifi/service/res -> packages/modules/Wifi/service/ServiceWifiResources/res
```

`frameworks/opt/net/wifi/service/res` does not exist, and no `Android.bp`/`.mk` references
it. A `PRODUCT_PACKAGE_OVERLAYS` directory only takes effect when a module's resource dir
matches, so this overlay is **never consumed** — `config_wifiSaeUpgradeEnabled` keeps its
AOSP default of `true` (`ServiceWifiResources/res/values/config.xml:803`).

Consistent with stock's own behaviour: the baseline connected as `networkType=TYPE_WPA3`
first try. SAE is not being suppressed on either build.

### A.9 Suggested next step

Rebuild the WiFi framework resource values into the GSI at the **correct** path
(`packages/modules/Wifi/service/ServiceWifiResources/res`), starting with
`config_wifi_framework_enable_associated_network_selection=false` and the two RSSI entry
thresholds. That is a `systemimage`-only change, so `rebuild.sh` applies and no vendor
repack is needed.

The alternative — restoring `/vendor/overlay` — requires rebuilding vendor and is the
worse option, since GammaOS's vendor is already a converted ext4 image.

Artifacts: `rg556work/stock111/` (super + extracted partitions), `rg556work/pacpick.py`.

---

## Appendix B: the fix, as built

### B.1 Mechanism correction

`PRODUCT_PACKAGE_OVERLAYS` **cannot** reach these values. `ServiceWifiResources` is
`apex_available: ["com.android.wifi"]` — a mainline module — and mainline module
resources are not customisable at build time. Adding
`device/phh/treble/overlay/packages/modules/Wifi/.../config.xml` was tried first and
produced `ninja: no work to do`; the built APK still read `true` / `-80` / `-77`.

The resources are declared `<overlayable name="WifiCustomization">` with policy
`odm|product|system|vendor`, and `aapt2 dump` marks them `OVERLAYABLE`. Overriding them
requires a **runtime_resource_overlay**, which is exactly what Anbernic stock does
(`/vendor/overlay/AospWifiOverlay_Marlin3` = `com.android.wifi.resources.uni_marlin3`).

### B.2 What was added

```
device/phh/treble/rro_overlays/WifiOverlay/Android.bp          runtime_resource_overlay, product_specific
device/phh/treble/rro_overlays/WifiOverlay/AndroidManifest.xml targetPackage/targetName/isStatic
device/phh/treble/rro_overlays/WifiOverlay/res/values/config.xml
device/phh/treble/base.mk                                      PRODUCT_PACKAGES += TrebleWifiOverlay
rebuild.sh                                                     JOBS= override (default -j$(nproc) exhausted RAM)
```

Values set (Unisoc's, replacing AOSP defaults):

```
config_wifi_framework_enable_associated_network_selection    false   (AOSP true)
config_wifi_framework_wifi_score_entry_rssi_threshold_24GHz   -70    (AOSP -80)
config_wifi_framework_wifi_score_entry_rssi_threshold_5GHz    -66    (AOSP -77)
```

### B.3 Verified before flashing

```
$ aapt2 dump xmltree --file AndroidManifest.xml TrebleWifiOverlay.apk
package="com.android.wifi.resources.treble"
E: overlay
  android:priority=1
  android:targetPackage="com.android.wifi.resources"
  android:targetName="WifiCustomization"
  android:isStatic=true

$ aapt2 dump resources TrebleWifiOverlay.apk
bool/config_wifi_framework_enable_associated_network_selection      false
integer/config_wifi_framework_wifi_score_entry_rssi_threshold_24GHz -70
integer/config_wifi_framework_wifi_score_entry_rssi_threshold_5GHz  -66
```

- Installed: `/system/product/overlay/TrebleWifiOverlay.apk`, 8542 bytes
  (the same size as Unisoc's own RRO APKs).
- Present inside the built `system.img` (`debugfs -R "ls -l /product/overlay"`).
- Rebuild took **1m56s** incremental.
- `super_bgN.img` repacked; `system_a` inside it is **bit-identical** to the built image
  (`86e83a66880f90af41d7eb958cbdf990`); vendor/odm/vendor_dlkm untouched.
- `GammaOS-Linux-Tools/extracted/super_full.img` resolves to the new super.

Build: `lineage-21.0-20260811-UNOFFICIAL-arm64_bgN.img`, 3,771,863,040 bytes.

### B.4 Post-flash verification

```bash
adb shell cmd overlay list | grep -i wifi          # expect [x] com.android.wifi.resources.treble
adb shell dumpsys wifi | grep -i "associated network selection"
```

Then re-run the Step 4 / 4b capture under matched conditions (charging, same screen
timeout) and append under a `## GammaOS Next` heading. The discriminating window is the
121-second screen-on idle: stock emitted nothing at all, so any activity there is the
anomaly.

If WiFi is unchanged, the next candidates are Unisoc's other two overlay values
(`config_wifi_fast_bss_transition_enabled`, `config_wifi_background_scan_support`, both
true on stock and false in AOSP), then H3 (HIDL-only vendor WiFi HAL under an Android 14
framework).

---

## GammaOS Next (google/lineage_arm64_bgN/tdgsi_arm64_ab:14/AP2A.240905.003/20260812:userdebug/test-keys)

Captured 2026-08-12, after flashing the `TrebleWifiOverlay` RRO and the
duration-haptics build. Same AP as the baseline (`ASUS_38_5G`, 5 GHz,
bssid `4c:ed:fb:b6:bb:3c`), device on USB power, screen timeout held off with
`svc power stayon usb` for the duration of the capture only.

Overlay confirmed active before capturing:

    com.android.wifi.resources
    [x] com.android.wifi.resources.treble

    isAssociatedNetworkSelectionEnabled=false

### Step 4: screen off/on cycle

Raw, unedited:

    08-12 23:07:47.169  1984  1984 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
    08-12 23:07:47.169  1984  1984 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 1' success
    08-12 23:08:16.669  1984  1984 I wpa_supplicant: wpa_driver_nl80211_driver_cmd, bss ifname : wlan0
    08-12 23:08:16.670  1984  1984 I wpa_supplicant: driver cmd 'SETSUSPENDMODE 0' success

Two invocations, both `success`, each paired to a screen transition:
`SETSUSPENDMODE 1` at screen-off, `SETSUSPENDMODE 0` at screen-on ~29.5 s later.
No unpaired or repeated calls.

### Step 4b: 121 s screen-on idle

    (empty)

**Zero** driver commands across the whole window. `dumpsys power` confirmed
`mWakefulness=Awake` at the end, so the screen genuinely stayed on and the
empty result is a real measurement rather than a missed window.

### Comparison with the stock baseline

| | Anbernic stock V1.16 | GammaOS Next (this build) |
|---|---|---|
| driver cmds on screen transition | fires, all `success` | fires, all `success` |
| pairing to screen state | strictly paired | strictly paired |
| 121 s screen-on idle | **0 commands** | **0 commands** |

GammaOS now matches stock in the discriminating window. The baseline's most
useful property was the empty idle window, and this build reproduces it.

### What this does and does not establish

It establishes that this build's suspend-mode behaviour is indistinguishable
from stock's over one capture, and that the RRO is active and effective at
runtime.

It does **not** establish that the dropouts are fixed. The reported fault is
intermittent and plays out over hours; a single clean three-minute capture
cannot see it. The overlay deletion remains measured fact, and the causal link
to the dropouts remains inference. Only extended normal use can settle that.
