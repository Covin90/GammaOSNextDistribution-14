#!/bin/bash
# Fast incremental rebuild -- the counterpart to build.sh.
#
# build.sh goes through lineage_build_unified/buildbot_unified.sh, which runs
# `make installclean` before every build (buildbot_unified.sh:157). That is
# correct for CI, where a from-scratch build is the point, but it throws away
# the staged output every time and costs ~2.5 hours. This script skips the
# installclean and builds straight into the existing out/, so a no-op rebuild
# takes ~14 seconds and a one-file change takes minutes.
#
# It also uses -j$(nproc) instead of the buildbot's physical-core count
# (buildbot_unified.sh:158 computes 8 on an 8c/16t part, leaving half the
# CPU idle).
#
# Usage:
#   bash rebuild.sh          # Lite  (arm64_bvN, no GApps)
#   bash rebuild.sh gapps    # Full  (arm64_bgN, with GApps)
#
# NOTE: out/ holds the intermediates for ONE variant at a time. Switching
# between bvN and bgN invalidates most of the graph (different
# PRODUCT_SOONG_NAMESPACES), so the first build after a switch is slow again.
# Iterate on one variant to stay fast.

set -e

case "${1:-lite}" in
    lite)  TARGET=lineage_arm64_bvN ;;
    gapps|full) TARGET=lineage_arm64_bgN ;;
    *) echo "Usage: bash rebuild.sh [lite|gapps]"; exit 1 ;;
esac

cd "$(dirname "$0")"
export HOME="$PWD/out/home"

source build/envsetup.sh > /dev/null
source vendor/lineage/vars/aosp_target_release

lunch "${TARGET}-${aosp_target_release}-userdebug" > /dev/null

# -j defaults to nproc, but the R8/javac/soong_zip steps are memory-hungry and
# a full-width build can exhaust RAM on a 32 GB box. Override with JOBS=n.
JOBS="${JOBS:-$(nproc)}"
echo "building with -j$JOBS"
WITH_ADB_INSECURE=true make -j"$JOBS" systemimage

IMG=out/target/product/tdgsi_arm64_ab/system.img
if [ -f "$IMG" ]; then
    mkdir -p out/home/build-output
    DEST="out/home/build-output/lineage-21.0-$(date -u +%Y%m%d)-UNOFFICIAL-${TARGET#lineage_}.img"
    cp -f "$IMG" "$DEST"
    echo ""
    echo "Image: $DEST"
    ls -lh "$DEST"
fi
