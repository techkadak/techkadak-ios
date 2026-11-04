#!/bin/bash
# Simulator test: fresh launch → home tak, crash check, bad JSON, offline, screenshots.
set -u
APP="$1"            # path to TechKadak.app (iphonesimulator build)
OUT="${2:-out}"
BID=in.techkadak.app
mkdir -p "$OUT/screens"
RES="$OUT/sim-results.txt"; : > "$RES"
log(){ echo "$*" | tee -a "$RES"; }

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
best=None
for rt,devs in d.items():
    if "iOS" not in rt: continue
    for x in devs:
        if not x.get("isAvailable",True): continue
        n=x["name"]
        if not n.startswith("iPhone"): continue
        score=(rt, 2 if n=="iPhone 16 Pro" else (1 if "Pro" in n and "Max" not in n else 0))
        if best is None or score>best[0]: best=(score,x["udid"],n,rt)
print(best[1]); print(best[2]+" | "+best[3], file=sys.stderr)
')
log "device: $UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 || true
xcrun simctl ui "$UDID" appearance dark || true

FAILS=0
crashcount(){ ls ~/Library/Logs/DiagnosticReports/ 2>/dev/null | grep -ci techkadak || true; }
C0=$(crashcount)

fresh(){ xcrun simctl uninstall "$UDID" $BID >/dev/null 2>&1; xcrun simctl install "$UDID" "$APP"; }
launch(){ # args...
  xcrun simctl terminate "$UDID" $BID >/dev/null 2>&1
  local o; o=$(xcrun simctl launch "$UDID" $BID "$@" 2>&1); echo "$o" | tail -1
  PID=$(echo "$o" | sed -n 's/.*: \([0-9][0-9]*\)$/\1/p' | tail -1)
}
alive(){ [ -n "${PID:-}" ] && ps -p "$PID" >/dev/null 2>&1; }
shot(){ xcrun simctl io "$UDID" screenshot --type=png "$OUT/screens/$1.png" >/dev/null 2>&1 && echo "shot $1"; }
marker(){ local c; c=$(xcrun simctl get_app_container "$UDID" $BID data 2>/dev/null); cat "$c/Documents/tk_home_reached.txt" 2>/dev/null; }
check(){ # name, need_marker
  if alive; then log "PASS alive: $1 (pid $PID)"; else log "FAIL died: $1"; FAILS=$((FAILS+1)); fi
  if [ "${2:-0}" = 1 ]; then m=$(marker); if [ -n "$m" ]; then log "PASS home: $1 -> $m"; else log "FAIL no-home-marker: $1"; FAILS=$((FAILS+1)); fi; fi
}

# 1) FRESH install, real launch, no args: splash live frames → onboarding
fresh
launch
sleep 0.35; shot 01-splash-live-a
sleep 0.5;  shot 01-splash-live-b
sleep 0.6;  shot 01-splash-live-c
sleep 0.7;  shot 01-splash-live-d
sleep 4;    shot 02-onboarding-live
check "fresh launch (splash+onboarding)" 0

# 2) FRESH install → home (onboarding skipped by arg), full splash, live data
fresh
launch -tkOnboard 0
sleep 12
shot 03-home-fresh
check "fresh launch to home" 1

# 3) splash frozen frames
for t in 0.07 0.14 0.25 0.35 0.45 0.55 0.63 0.70 0.76 0.86 0.93; do
  launch -tkOnboard 0 -tkSplashAt $t; sleep 2.5; shot "04-splash-t$t"
done
check "splash frames" 0

# 4) onboarding pages
for pg in 0 1 2 3; do launch -tkOnboard 1 -tkNoSplash 1 -tkOnboardPage $pg; sleep 3; shot "05-onboarding-$pg"; done
check "onboarding" 0

# 5) themes + screens
for th in dark glass light amoled; do launch -tkOnboard 0 -tkNoSplash 1 -tkTheme $th; sleep 6; shot "10-home-$th"; check "home $th" 1; done
SLUG=$(python3 -c 'import json;print(json.load(open("TechKadak/Resources/apps.json"))["apps"][0]["slug"])')
launch -tkOnboard 0 -tkNoSplash 1 -tkTheme dark -tkOpenApp "$SLUG"; sleep 6; shot 20-detail-dark; check "detail dark" 0
launch -tkOnboard 0 -tkNoSplash 1 -tkTheme glass -tkOpenApp "$SLUG"; sleep 6; shot 21-detail-glass; check "detail glass" 0
launch -tkOnboard 0 -tkNoSplash 1 -tkTheme glass -tkOpenApp photopea; sleep 6; shot 22-detail-web-glass
launch -tkOnboard 0 -tkNoSplash 1 -tkTheme dark -tkTab settings; sleep 4; shot 30-settings-dark; check "settings" 0
launch -tkOnboard 0 -tkNoSplash 1 -tkTheme glass -tkTab settings; sleep 4; shot 31-settings-glass
launch -tkOnboard 0 -tkNoSplash 1 -tkTheme glass -tkTab kits; sleep 5; shot 40-kits-glass; check "kits" 0
launch -tkOnboard 0 -tkNoSplash 1 -tkTheme dark -tkOpenKit student; sleep 5; shot 41-kit-student; check "kit detail" 0
launch -tkOnboard 0 -tkNoSplash 1 -tkTheme dark -tkTab search -tkSearch pdf; sleep 4; shot 50-search; check "search" 0
launch -tkOnboard 0 -tkNoSplash 1 -tkTheme light -tkTab favs; sleep 3; shot 60-favs-light; check "favs" 0

# 6) BAD JSON from server → must still open home (cache/bundled)
fresh
launch -tkOnboard 0 -tkNoSplash 1 -tkAppsURL "https://techkadak.github.io/index.html"
sleep 8; shot 70-badjson; check "bad JSON fresh" 1
launch -tkOnboard 0 -tkNoSplash 1 -tkAppsURL "https://techkadak.github.io/does-not-exist-404.json"
sleep 6; check "404 JSON" 1

# 7) OFFLINE fresh install → bundled list
fresh
launch -tkOnboard 0 -tkNoSplash 1 -tkOffline 1
sleep 6; shot 71-offline-fresh; check "offline fresh" 1

# 8) relaunch after everything (cache path)
launch -tkOnboard 0
sleep 8; check "relaunch with cache" 1

C1=$(crashcount)
if [ "$C1" != "$C0" ]; then log "FAIL crash reports: $C0 -> $C1"; ls -la ~/Library/Logs/DiagnosticReports/ | grep -i techkadak | tee -a "$RES"; FAILS=$((FAILS+1)); cp ~/Library/Logs/DiagnosticReports/*TechKadak* "$OUT/" 2>/dev/null; else log "PASS no crash reports ($C1)"; fi
log "FAILS=$FAILS"
xcrun simctl shutdown "$UDID" || true
exit $FAILS
