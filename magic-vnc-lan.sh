#!/usr/bin/env bash
# MAGIC VNC — uruchomienie TigerVNC na zwykłym prywatnym IP Debiana (LAN)
set -Eeuo pipefail
umask 077

VNC_USER="magic"
DISPLAY_NUM=":1"
VNC_PORT="5901"
CFG_DIR="/home/magic/.config/tigervnc"
GLOBAL_CFG="/etc/tigervnc/vncserver-config-defaults"
USERS_CFG="/etc/tigervnc/vncserver.users"
BACKUP="/root/magic-vnc-lan-backup-$(date +%Y%m%d-%H%M%S)"

log(){ printf '\n[MAGIC VNC] %s\n' "$*"; }
fail(){ echo "[BŁĄD] $*" >&2; exit 1; }
trap 'rc=$?; echo "[BŁĄD] Skrypt zakończony kodem $rc, linia $LINENO." >&2; exit "$rc"' ERR

[[ $EUID -eq 0 ]] || fail "Uruchom: sudo bash magic-vnc-lan.sh"
id "$VNC_USER" >/dev/null 2>&1 || fail "Brak użytkownika magic."
command -v systemctl >/dev/null || fail "Brak systemd."
command -v ip >/dev/null || fail "Brak iproute2."
command -v tigervncserver >/dev/null || fail "TigerVNC nie jest zainstalowany."
command -v tigervncpasswd >/dev/null || fail "Brak tigervncpasswd."
[[ -f /usr/share/xsessions/plasmax11.desktop ]] || fail "Brak sesji KDE Plasma X11 (plasmax11)."

# Determine LAN address used by default route.
LAN_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
[[ -n "$LAN_IP" ]] || fail "Nie mogę wykryć adresu IPv4. Sprawdź połączenie sieciowe."

# Only bind to private IPv4 to avoid exposing VNC on a public address.
python3 - "$LAN_IP" <<'PY'
import ipaddress, sys
ip = ipaddress.ip_address(sys.argv[1])
if not ip.is_private or ip.is_loopback or ip.is_link_local:
    raise SystemExit("Adres nie jest prywatnym adresem LAN. Przerywam, aby nie wystawić VNC publicznie.")
PY

mkdir -p "$BACKUP" /etc/tigervnc "$CFG_DIR"
chmod 700 "$BACKUP" "$CFG_DIR"
for f in "$GLOBAL_CFG" "$USERS_CFG" "$CFG_DIR/config.pl" "$CFG_DIR/config"; do
  [[ ! -e "$f" ]] || cp -a "$f" "$BACKUP/"
done

log "Wykryty adres LAN: $LAN_IP"
log "Kopię poprzednich ustawień zapisuję w: $BACKUP"

# Debian 13 TigerVNC system defaults use Perl syntax. The interface assignment
# must appear BEFORE localhost=no for the selected interface to take effect.
cat > "$GLOBAL_CFG" <<EOF
\$interface = "$LAN_IP";
\$localhost = "no";
\$rfbport = $VNC_PORT;
\$securityTypes = "VncAuth";
\$geometry = "1600x900";
\$depth = 24;
\$session = "plasmax11";
EOF
chmod 644 "$GLOBAL_CFG"

# Avoid stale per-user config overriding the system defaults.
if [[ -f "$CFG_DIR/config.pl" ]]; then
  mv "$CFG_DIR/config.pl" "$BACKUP/config.pl.disabled"
fi
if [[ -f "$CFG_DIR/config" ]]; then
  mv "$CFG_DIR/config" "$BACKUP/config.disabled"
fi

printf '%s=%s\n' "$DISPLAY_NUM" "$VNC_USER" > "$USERS_CFG"
chmod 644 "$USERS_CFG"

if [[ ! -s "$CFG_DIR/passwd" ]]; then
  log "Brak hasła VNC — ustaw je teraz."
  runuser -u "$VNC_USER" -- tigervncpasswd
fi
[[ -s "$CFG_DIR/passwd" ]] || fail "Nie znaleziono pliku hasła VNC."
chown "$VNC_USER:$VNC_USER" "$CFG_DIR/passwd"
chmod 600 "$CFG_DIR/passwd"

log "Sprawdzam konfigurację TigerVNC..."
tigervncserver -help >/dev/null 2>&1 || true

log "Restartuję wyłącznie usługę TigerVNC..."
systemctl daemon-reload
systemctl enable "tigervncserver@${DISPLAY_NUM}"
systemctl restart "tigervncserver@${DISPLAY_NUM}"

sleep 3
log "Status:"
systemctl --no-pager --full status "tigervncserver@${DISPLAY_NUM}" || true

log "Nasłuch:"
ss -lntp | grep -E ":${VNC_PORT}([[:space:]]|$)" || true

echo
echo "============== GOTOWE / MAGIC VNC =============="
echo "Adres Debiana w LAN: $LAN_IP"
echo "Port VNC:            $VNC_PORT"
echo "Adres do klienta:    ${LAN_IP}:${VNC_PORT}"
echo "Użytkownik sesji:    $VNC_USER"
echo "Hasło:               hasło VNC zapisane w TigerVNC"
echo "Sesja:               KDE Plasma X11"
echo "Kopia konfiguracji:  $BACKUP"
echo
echo "VNC jest przypięty do prywatnego adresu LAN, nie do wszystkich interfejsów."
echo "Nie przekierowuj portu 5901 na routerze do Internetu."
echo "Dostęp spoza LAN: użyj WireGuard/VPN."
echo "================================================"
