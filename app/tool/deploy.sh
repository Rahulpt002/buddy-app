#!/usr/bin/env bash
# Build the debug APK and install it on the DeskPanel phone, over USB or Wi-Fi.
#
#   app/tool/deploy.sh            # build + install + launch
#   app/tool/deploy.sh --no-build # install the last build
#
# Wi-Fi: turn on Developer options → Wireless debugging on the phone (once paired with
# this Mac it reconnects by itself). The port changes every time it's toggled, so the
# phone is found by mDNS each run. Won't launch the app while the phone is in a call or
# locked (it still installs).
set -euo pipefail
cd "$(dirname "$0")/.."

APK=build/app/outputs/flutter-apk/app-debug.apk
PKG=com.deskpanel.deskpanel

if [[ "${1:-}" != "--no-build" ]]; then
  flutter build apk --debug
fi

pick_device() {
  # 1) Any device already attached (USB first, then an existing Wi-Fi connection).
  local usb wifi
  usb=$(adb devices | awk 'NR>1 && $2=="device" && $1 !~ /:|_adb-tls-connect/ {print $1; exit}')
  [[ -n "$usb" ]] && { echo "$usb"; return; }
  wifi=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')
  [[ -n "$wifi" ]] && { echo "$wifi"; return; }

  # 2) Find wireless debugging on the network. adb's default mDNS backend misses it on
  #    macOS, so use the Openscreen one (restarts the adb server if needed).
  local addr=""
  for _ in 1 2 3 4 5; do
    addr=$(adb mdns services 2>/dev/null | awk '/_adb-tls-connect/ {print $3; exit}')
    [[ -n "$addr" ]] && break
    if [[ "${ADB_MDNS_OPENSCREEN:-}" != 1 ]]; then
      export ADB_MDNS_OPENSCREEN=1
      adb kill-server >/dev/null 2>&1 || true
      adb start-server >/dev/null 2>&1
    fi
    sleep 2
  done
  [[ -z "$addr" ]] && return 1
  adb connect "$addr" >&2
  sleep 1
  adb devices | awk -v a="$addr" 'NR>1 && $1==a && $2=="device" {print $1}'
}

DEV=$(pick_device) || true
if [[ -z "${DEV:-}" ]]; then
  echo "No phone found. Plug it in, or turn on Wireless debugging (same Wi-Fi as this Mac)." >&2
  exit 1
fi
echo "Phone: $DEV ($(adb -s "$DEV" shell getprop ro.product.model | tr -d '\r'))"

adb -s "$DEV" install -r "$APK"

in_call=$(adb -s "$DEV" shell dumpsys telephony.registry | grep -m1 -o 'mCallState=[0-9]' | cut -d= -f2 || true)
locked=$(adb -s "$DEV" shell dumpsys window | grep -m1 -o 'isKeyguardShowing=[a-z]*' | cut -d= -f2 || true)
if [[ "${in_call:-0}" != 0 ]]; then
  echo "Installed. Not launching: the phone is in a call."
elif [[ "${locked:-false}" == true ]]; then
  echo "Installed. Not launching: the phone is locked."
else
  adb -s "$DEV" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  echo "Installed and launched."
fi
