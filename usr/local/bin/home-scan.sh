#!/usr/bin/env bash
# home-scan.sh — Robust LAN scanner (Arch-friendly)
# Finds interface via default route, supports --iface/--subnet overrides,
# shows hostnames, vendor, colorized status, and good diagnostics.
# Requires: arp-scan, nmap, iproute2, awk, grep, sed, sort

set -u

# -------- options --------
NO_COLOR="${NO_COLOR:-}"
IFACE=""
SUBNET=""
DEBUG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-color) NO_COLOR=1; shift ;;
    --iface) IFACE="${2:-}"; shift 2 ;;
    --subnet) SUBNET="${2:-}"; shift 2 ;;
    --debug) DEBUG=1; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# -------- colors --------
if [[ -t 1 && -z "${NO_COLOR}" ]]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=""; C_DIM=""; C_BOLD=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_BLUE=""
fi

# -------- deps --------
for cmd in ip nmap arp-scan awk grep sed sort; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed. Try: sudo pacman -S $cmd"
    exit 1
  fi
done

# -------- helpers --------
log() { [[ $DEBUG -eq 1 ]] && echo "${C_DIM}[debug] $*${C_RESET}" >&2; }

is_virtual_iface() {
  local n="$1"
  [[ "$n" == "lo" || "$n" == "docker0" || "$n" == br-* || "$n" == veth* || "$n" == virbr* || \
     "$n" == tailscale* || "$n" == wg* || "$n" == tun* || "$n" == zt* || "$n" == cni* || "$n" == podman* ]]
}

# -------- detect iface from default route if not provided --------
if [[ -z "$IFACE" ]]; then
  DEFAULT_LINE="$(ip -o -4 route show to default 2>/dev/null | head -n1)"
  IFACE="$(awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1)}}' <<< "$DEFAULT_LINE")"
  SRC_IP="$(awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1)}}' <<< "$DEFAULT_LINE")"
  log "default route line: $DEFAULT_LINE"
  log "default dev: $IFACE  src: $SRC_IP"

  # Fall back to first global IPv4 interface if default route missing (rare)
  if [[ -z "$IFACE" ]]; then
    IFACE="$(ip -o -4 addr show scope global up | awk '{print $2}' | head -n1)"
    log "fallback iface: $IFACE"
  fi

  # Avoid virtual interfaces
  if [[ -n "$IFACE" ]] && is_virtual_iface "$IFACE"; then
    log "iface from default route looks virtual: $IFACE"
    IFACE="$(ip -o -4 addr show scope global up | awk '{print $2}' | while read -r i; do
      if ! is_virtual_iface "$i"; then echo "$i"; fi
    done | head -n1)"
    log "picked non-virtual iface: $IFACE"
  fi
fi

if [[ -z "$IFACE" ]]; then
  echo "Error: couldn’t auto-detect an active LAN interface."
  echo "Try specifying one: ./home-scan.sh --iface wlp3s0"
  exit 1
fi

# -------- detect subnet if not provided --------
if [[ -z "$SUBNET" ]]; then
  SUBNET="$(ip -o -4 addr show dev "$IFACE" scope global | awk '{print $4}' | head -n1)"
  log "raw CIDR for $IFACE: $SUBNET"
fi

if [[ -z "$SUBNET" ]]; then
  echo "Error: couldn’t determine IPv4 subnet for ${IFACE}."
  echo "Provide it explicitly, e.g.: --subnet 192.168.1.0/24"
  exit 1
fi

SELF_IP="$(ip -o -4 addr show dev "$IFACE" | awk '{print $4}' | cut -d/ -f1 | head -n1)"

echo "${C_BOLD}🔍 Scanning on:${C_RESET} ${C_BLUE}${IFACE}${C_RESET} ${C_DIM}(${SUBNET})${C_RESET}"
[[ -n "${SELF_IP}" ]] && echo "${C_DIM}Your IP:${C_RESET} ${SELF_IP}"
echo "--------------------------------------------------------------------------------"

# -------- scans --------
# Try to warm sudo cache quietly (ignore failures)
sudo -n true >/dev/null 2>&1 || true

# arp-scan: IP, MAC, Vendor
ARP_RAW="$(sudo arp-scan --interface="$IFACE" --retry=3 --timeout=400 --localnet 2>/dev/null | \
          grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' || true)"

# If nothing came back, try explicit subnet form
if [[ -z "$ARP_RAW" ]]; then
  ARP_RAW="$(sudo arp-scan --interface="$IFACE" --retry=3 --timeout=400 "$SUBNET" 2>/dev/null | \
            grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' || true)"
fi

# nmap: hostnames + who’s up (layer-3)
declare -A HOSTNAMES
declare -A IS_UP
LAST_IP=""

while IFS= read -r line; do
  if [[ $line =~ ^Nmap\ scan\ report\ for\ (.*)\ \(([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\)$ ]]; then
    HOST="${BASH_REMATCH[1]}"; IP="${BASH_REMATCH[2]}"; HOSTNAMES["$IP"]="$HOST"; LAST_IP="$IP"
  elif [[ $line =~ ^Nmap\ scan\ report\ for\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    IP="${BASH_REMATCH[1]}"; HOSTNAMES["$IP"]="" ; LAST_IP="$IP"
  elif [[ $line =~ ^Host\ is\ up ]]; then
    if [[ -n "$LAST_IP" ]]; then IS_UP["$LAST_IP"]=1; fi
  fi
done < <(sudo nmap -sn "$SUBNET" 2>/dev/null)

# If arp-scan failed, synthesize rows from ip neigh for hosts nmap saw
if [[ -z "$ARP_RAW" ]]; then
  TMP=""
  for ip in "${!IS_UP[@]}"; do
    mac="$(ip neigh show "$ip" 2>/dev/null | awk '/lladdr/ {for(i=1;i<=NF;i++) if($i=="lladdr"){print $(i+1)}}' | head -n1)"
    [[ -z "$mac" ]] && mac="(unknown)"
    TMP+="${ip}\t${mac}\t(Unknown)\n"
  done
  # shellcheck disable=SC2059
  printf -v ARP_RAW "%b" "$TMP"
fi

# -------- header --------
printf "%-15s | %-30s | %-17s | %-36s | %s\n" "IP Address" "Hostname" "MAC Address" "Vendor" "Status"
echo "---------------------------------------------------------------------------------------------------------------------------------------"

# -------- merge & print --------
if [[ -z "$ARP_RAW" ]]; then
  echo "No devices found. (Network isolation/VPN?)"
else
  # Sort numerically by IP octets
  echo "$ARP_RAW" | while IFS= read -r line; do
    IP=$(awk '{print $1}' <<< "$line")
    MAC=$(awk '{print $2}' <<< "$line")
    VENDOR=$(echo "$line" | cut -f3-)
    [[ -z "$VENDOR" ]] && VENDOR="(Unknown)"

    HOST="${HOSTNAMES[$IP]:-}"
    STATUS="OFFLINE?"
    if [[ -n "${IS_UP[$IP]:-}" ]]; then STATUS="ONLINE"; fi

    # colorize
    if [[ "$STATUS" == "ONLINE" ]]; then
      STATUS="${C_GREEN}ONLINE${C_RESET}"
    else
      STATUS="${C_RED}OFFLINE?${C_RESET}"
    fi
    if [[ "$VENDOR" =~ ^\(*[Uu]nknown\)*$ ]]; then
      VENDOR="${C_YELLOW}${VENDOR}${C_RESET}"
    fi
    if [[ -n "$SELF_IP" && "$IP" == "$SELF_IP" ]]; then
      HOST="${HOST:+$HOST }${C_DIM}(this machine)${C_RESET}"
    fi

    printf "%-15s | %-30s | %-17s | %-36s | %s\n" "$IP" "$HOST" "$MAC" "$VENDOR" "$STATUS"
  done | sort -t . -k1,1n -k2,2n -k3,3n -k4,4n
fi

echo "---------------------------------------------------------------------------------------------------------------------------------------"
echo "✅ Done. ${C_DIM}Hints: use --iface/--subnet to override; --debug for details; --no-color for plain output.${C_RESET}"

if [[ $DEBUG -eq 1 ]]; then
  echo "${C_DIM}Routes:${C_RESET}"; ip -4 route show
  echo "${C_DIM}Addresses on ${IFACE}:${C_RESET}"; ip -o -4 addr show dev "$IFACE"
fi
