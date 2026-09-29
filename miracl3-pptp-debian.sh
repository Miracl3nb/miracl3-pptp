#!/bin/bash
# ================================================================
#  miracl3-pptp-debian.sh
#  Instalación y configuración completa de VPN PPTP
#  Soporta: Arch, Manjaro, Debian 13, Ubuntu y derivados
# ================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() {
  echo -e "${RED}[ERR ]${NC} $1"
  exit 1
}
sep() { echo -e "${BOLD}────────────────────────────────────────────${NC}"; }
title() { echo -e "\n${BOLD}${CYAN}  ▸ $1${NC}\n"; }
ask() { echo -e "${YELLOW}[?]${NC} $1"; }

# ── Root check ───────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Ejecutar como root: sudo bash $0"

REAL_USER="${SUDO_USER:-$USER}"

# Sin un usuario real identificado, el fichero de sudoers se escribiría con el
# usuario en blanco. Eso no es un no-op: sudo descarta el resto de sudoers si una
# línea no parsea, así que dejaría al equipo sin poder usar sudo en absoluto.
[[ -z "$REAL_USER" || "$REAL_USER" == "root" ]] &&
  error "No se pudo detectar el usuario real. Lanza el script con: sudo bash $0"

id -u "$REAL_USER" >/dev/null 2>&1 ||
  error "El usuario '$REAL_USER' no existe en el sistema. Lanza el script con: sudo bash $0"

REAL_HOME=$(eval echo "~$REAL_USER")

# ── Detectar distro ──────────────────────────────────────────
detect_distro() {
  [[ -f /etc/os-release ]] || error "No se pudo detectar la distribución."
  source /etc/os-release
  DISTRO_ID="${ID,,}"
  DISTRO_LIKE="${ID_LIKE,,}"
  PRETTY_NAME="${PRETTY_NAME:-$ID}"
  if [[ "$DISTRO_ID" == "arch" || "$DISTRO_LIKE" == *"arch"* || "$DISTRO_ID" == "manjaro" ]]; then
    DISTRO_FAMILY="arch"
  elif [[ "$DISTRO_ID" == "debian" || "$DISTRO_LIKE" == *"debian"* ||
    "$DISTRO_ID" == "ubuntu" || "$DISTRO_LIKE" == *"ubuntu"* ]]; then
    DISTRO_FAMILY="debian"
  else
    error "Distro no soportada: $DISTRO_ID."
  fi
}

# ── Detectar Hyprland ────────────────────────────────────────
detect_hyprland() {
  HYPRLAND=false
  HYPR_DIR="$REAL_HOME/.config/hypr"
  if [[ -d "$HYPR_DIR" ]] || command -v Hyprland &>/dev/null ||
    [[ "${XDG_CURRENT_DESKTOP,,}" == *"hyprland"* ]] ||
    [[ "${XDG_SESSION_DESKTOP,,}" == *"hyprland"* ]]; then
    HYPRLAND=true
  fi
}

# ── Instalar paquetes ────────────────────────────────────────
install_packages() {
  title "Instalando dependencias"
  case "$DISTRO_FAMILY" in
  arch)
    info "Actualizando base de datos pacman..."
    pacman -Sy --noconfirm >/dev/null 2>&1
    for pkg in pptpclient networkmanager-pptp psmisc; do
      if pacman -Qi "$pkg" &>/dev/null; then
        warn "$pkg ya instalado."
      else
        info "Instalando $pkg..."
        pacman -S --noconfirm "$pkg" >/dev/null 2>&1 && ok "$pkg instalado."
      fi
    done
    ;;
  debian)
    info "Cargando módulos de Kernel (PPTP/MPPE)..."
    modprobe ppp_mppe 2>/dev/null || true
    modprobe pptp 2>/dev/null || true

    info "Actualizando lista apt..."
    apt-get update -qq >/dev/null 2>&1
    for pkg in pptp-linux network-manager-pptp network-manager-pptp-gnome psmisc iproute2; do
      if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        warn "$pkg ya instalado."
      else
        info "Instalando $pkg..."
        apt-get install -y -qq "$pkg" >/dev/null 2>&1 && ok "$pkg instalado."
      fi
    done
    ;;
  esac
}

# ════════════════════════════════════════════════════════════
#  BANNER Y DETECCIÓN
# ════════════════════════════════════════════════════════════
# "|| true" porque con "set -e" un "clear" fallido (TERM no definido al lanzar
# el script desde otro contexto) abortaría toda la instalación sin razón.
clear || true
echo -e "${BOLD}${CYAN}"
echo "  ██╗   ██╗██████╗ ███╗   ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗ "
echo "  ██║   ██║██╔══██╗████╗  ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗"
echo "  ██║   ██║██████╔╝██╔██╗ ██║    ███████╗█████╗     ██║   ██║   ██║██████╔╝"
echo "  ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ "
echo "   ╚████╔╝ ██║     ██║ ╚████║    ███████║███████╗   ██║   ╚██████╔╝██║     "
echo "    ╚═══╝  ╚═╝     ╚═╝  ╚═══╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     "
echo -e "${NC}"
echo -e "   ${BOLD}Configurador de VPN PPTP — Fix Debian 13 / Arch${NC}"
sep

detect_distro
detect_hyprland

echo -e "\n  ${BOLD}Sistema detectado:${NC}"
echo -e "  • Distro     : ${CYAN}${PRETTY_NAME}${NC}"
echo -e "  • Familia    : ${CYAN}${DISTRO_FAMILY}${NC}"
echo -e "  • Hyprland   : ${CYAN}${HYPRLAND}${NC}"
echo -e "  • Usuario    : ${CYAN}${REAL_USER}${NC}\n"
sep

# ════════════════════════════════════════════════════════════
#  DATOS DE CONEXIÓN
# ════════════════════════════════════════════════════════════
title "Datos de la conexión VPN"

read -p "  Nombre de la conexión (ej: vpn-oficina):            " VPN_NAME
[[ -z "$VPN_NAME" ]] && error "El nombre no puede estar vacío."

read -p "  Servidor VPN (ej: vpn.empresa.net):            " VPN_SERVER
[[ -z "$VPN_SERVER" ]] && error "El servidor no puede estar vacío."

read -p "  Usuario (ej: usuario@dominio.com):             " VPN_USER
[[ -z "$VPN_USER" ]] && error "El usuario no puede estar vacío."

read -s -p "  Contraseña:                                    " VPN_PASS
echo ""
[[ -z "$VPN_PASS" ]] && error "La contraseña no puede estar vacía."

read -p "  Red interna a rutear (ej: 10.1.0.0/16):      " VPN_ROUTE
[[ -z "$VPN_ROUTE" ]] && error "La red no puede estar vacía."

# Vacía por defecto: ${USE_PEERDNS:+usepeerdns} solo añade la opción si
# tiene contenido (usar "false" aquí la activaría siempre).
USE_PEERDNS=""
ask "¿Usar también los DNS que entrega el servidor VPN? [s/N]: "
read -r DNS_RESP
[[ "${DNS_RESP,,}" == "s" ]] && USE_PEERDNS="yes"

SETUP_KEYBINDS=false
if [[ "$HYPRLAND" == true ]]; then
  echo ""
  ask "Se detectó Hyprland. ¿Configurar keybinds para VPN? [s/N]: "
  read -r KB_RESP
  [[ "${KB_RESP,,}" == "s" ]] && SETUP_KEYBINDS=true
fi

echo ""
sep

# ════════════════════════════════════════════════════════════
#  INSTALACIÓN DE PAQUETES
# ════════════════════════════════════════════════════════════
install_packages
sep

# ════════════════════════════════════════════════════════════
#  CONFIGURACIÓN PPPD
# ════════════════════════════════════════════════════════════
title "Configurando pppd"

PEERS_FILE="/etc/ppp/peers/$VPN_NAME"
CHAP_FILE="/etc/ppp/chap-secrets"

mkdir -p /etc/ppp/peers

[[ -f "$PEERS_FILE" ]] && cp "$PEERS_FILE" "${PEERS_FILE}.bak"

tee "$PEERS_FILE" >/dev/null <<EOF
# La línea "pty" es la que arranca el cliente PPTP: sin ella pppd no tiene por
# dónde conectar y falla con "pppd can't be run without a pty".
pty "pptp $VPN_SERVER --nolaunchpppd"
name $VPN_USER
remotename PPTP
require-mppe-128
require-mschap-v2
noauth
noipdefault
nodeflate
nobsdcomp
maxfail 1
holdoff 5
${USE_PEERDNS:+usepeerdns}

# Sin "defaultroute" ni "replacedefaultroute": el tráfico de internet sigue
# saliendo por la interfaz normal (WiFi o cable) y solo la red interna se
# enruta por el túnel, que se gestiona en /etc/ppp/ip-up.d/10-vpnroute.
EOF
ok "Archivo de peers creado: $PEERS_FILE"

touch "$CHAP_FILE"
chmod 600 "$CHAP_FILE"
sed -i "/^${VPN_USER//\//\\/}[[:space:]]*PPTP/d" "$CHAP_FILE"
echo "$VPN_USER PPTP $VPN_PASS *" >>"$CHAP_FILE"
ok "Credenciales guardadas: $CHAP_FILE"

# ════════════════════════════════════════════════════════════
#  RUTAS AUTOMÁTICAS ip-up.d / ip-down.d
# ════════════════════════════════════════════════════════════
title "Configuando rutas automáticas"

mkdir -p /etc/ppp/ip-up.d /etc/ppp/ip-down.d

# IMPORTANTE: pppd no ejecuta por sí solo los hooks de /etc/ppp/ip-up.d; los
# lanza /etc/ppp/ip-up a través de "run-parts". Y "run-parts" IGNORA cualquier
# archivo con extensión o con punto (p.ej. vpn-route.sh, vpn-route.old), por eso
# el hook va sin extensión y con prefijo numérico, que además fija el orden.
HOOK_NAME="10-vpnroute"

# Limpia los hooks que dejaba la versión anterior del script. Se llamaban
# "vpn-route.sh" y run-parts los descartaba siempre, así que la ruta interna
# nunca llegaba a instalarse: la VPN conectaba pero el ping se perdía.
for legacy in vpn-route.sh vpn-route vpn_route.sh; do
  rm -f "/etc/ppp/ip-up.d/$legacy" "/etc/ppp/ip-down.d/$legacy"
done

tee "/etc/ppp/ip-up.d/$HOOK_NAME" >/dev/null <<EOF
#!/bin/bash
# Añade la ruta de la red interna al levantar el túnel.
IFACE="\${1:-ppp0}"
LOG=/var/log/ppp-vpnroute.log

{
  echo "--- \$(date '+%F %T') ip-up dev=\$IFACE ruta=$VPN_ROUTE ---"
  # "replace" en vez de "add": idempotente, se puede reejecutar sin fallar.
  # El MTU se fija en la misma orden: con MPPE el MTU efectivo del túnel baja
  # (~1396) y algunos equipos intermedios descartan paquetes grandes, dejando
  # conexiones colgadas.
  if ip route replace $VPN_ROUTE dev "\$IFACE" mtu 1400; then
    echo "OK: $VPN_ROUTE dev \$IFACE"
  else
    echo "ERROR: no se pudo instalar la ruta $VPN_ROUTE dev \$IFACE"
  fi
} >>"\$LOG" 2>&1
EOF
chmod +x "/etc/ppp/ip-up.d/$HOOK_NAME"

tee "/etc/ppp/ip-down.d/$HOOK_NAME" >/dev/null <<EOF
#!/bin/bash
# Quita la ruta de la red interna al bajar el túnel.
IFACE="\${1:-ppp0}"
ip route del $VPN_ROUTE dev "\$IFACE" 2>/dev/null || true
EOF
chmod +x "/etc/ppp/ip-down.d/$HOOK_NAME"

# En Debian/Ubuntu el /etc/ppp/ip-up del paquete YA invoca "run-parts" sobre
# /etc/ppp/ip-up.d, así que no hay que tocarlo: añadir el bucle otra vez
# ejecutaría el hook dos veces. Solo se parchea cuando el script del sistema NO
# llama al directorio .d (típico en Arch o en instalaciones antiguas), que antes
# era justo lo que pasaba porque el grep buscaba "*.sh" y no encontraba nada.
HOOK_MARKER="# hook-vpnroute-miracl3"

patch_runner() {
  local runner="$1" dir_name="$2"

  if [[ ! -f "$runner" ]]; then
    tee "$runner" >/dev/null <<RUNNER
#!/bin/sh
$HOOK_MARKER
PATH=/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin
export PATH
for file in /etc/ppp/$dir_name/[0-9]*-vpnroute; do
  [ -x "\$file" ] && "\$file" "\$@"
done
RUNNER
    chmod +x "$runner"
    return 0
  fi

  if grep -qF "$dir_name" "$runner"; then
    return 0
  fi

  if ! grep -qF "$HOOK_MARKER" "$runner"; then
    cp "$runner" "${runner}.bak"
    tee -a "$runner" >/dev/null <<RUNNER

$HOOK_MARKER
for file in /etc/ppp/$dir_name/[0-9]*-vpnroute; do
  [ -x "\$file" ] && "\$file" "\$@"
done
RUNNER
  fi
}

patch_runner /etc/ppp/ip-up ip-up.d
patch_runner /etc/ppp/ip-down ip-down.d

# Verificación: que el hook quede con nombre válido para run-parts es
# exactamente lo que fallaba antes, así que se comprueba en vez de suponerlo.
for dir in /etc/ppp/ip-up.d /etc/ppp/ip-down.d; do
  if run-parts --test "$dir" 2>/dev/null | grep -q "$HOOK_NAME"; then
    ok "run-parts detecta $dir/$HOOK_NAME"
  else
    error "run-parts NO detecta $dir/$HOOK_NAME: la ruta no se aplicará al conectar."
  fi
done

ok "Hooks de rutas configurados: /etc/ppp/ip-up.d/$HOOK_NAME y /etc/ppp/ip-down.d/$HOOK_NAME"
sep

# ════════════════════════════════════════════════════════════
#  BINARIOS
# ════════════════════════════════════════════════════════════
PPPD_BIN=$(which pppd 2>/dev/null || echo "/usr/sbin/pppd")
KILLALL_BIN=$(which killall 2>/dev/null || echo "/usr/bin/killall")
IP_BIN=$(which ip 2>/dev/null || echo "/usr/bin/ip")

# ════════════════════════════════════════════════════════════
#  SCRIPTS DE CONTROL (CON SUDO INCORPORADO)
# ════════════════════════════════════════════════════════════
title "Creando scripts de control"

tee /usr/local/bin/vpn-connect >/dev/null <<SCRIPT
#!/bin/bash
VPN_NAME="$VPN_NAME"

if pgrep pppd > /dev/null 2>&1; then
    echo "Limpiando conexiones pppd previas..."
    sudo $KILLALL_BIN -9 pppd 2>/dev/null || true
    sleep 2
fi

echo "Conectando \$VPN_NAME..."
sudo $PPPD_BIN call "\$VPN_NAME"

for i in \$(seq 1 20); do
    $IP_BIN link show ppp0 &>/dev/null && break
    sleep 1
done

if ! $IP_BIN link show ppp0 &>/dev/null; then
    echo "Error: ppp0 no levantó."
    notify-send -u critical "VPN" "❌ Error al conectar" 2>/dev/null || true
    exit 1
fi

sleep 2
IP_LOCAL=\$($IP_BIN addr show ppp0 2>/dev/null | grep 'inet ' | awk '{print \$2}')

# Red de seguridad: si el hook de ip-up.d no llegó a ejecutarse, el túnel
# levanta pero NO hay ruta a la red interna (el síntoma "conecta pero no ping").
# Se comprueba y, si falta, se instala aquí para que vpn-connect nunca fallé.
if ! $IP_BIN route show $VPN_ROUTE | grep -q "dev ppp0"; then
    echo "El hook de rutas no se ejecutó; instalando $VPN_ROUTE a mano..."
    sudo $IP_BIN route replace $VPN_ROUTE dev ppp0 mtu 1400 2>/dev/null || true
fi

if $IP_BIN route show $VPN_ROUTE | grep -q "dev ppp0"; then
    echo "✔ VPN conectada — IP: \$IP_LOCAL — ruta $VPN_ROUTE activa"
    notify-send -u normal "VPN" "✅ Conectada — \$IP_LOCAL" 2>/dev/null || true
else
    echo "⚠ VPN conectada a \$IP_LOCAL pero SIN ruta a $VPN_ROUTE"
    echo "  Revisa /var/log/ppp-vpnroute.log"
    notify-send -u critical "VPN" "⚠ Conectada sin ruta a $VPN_ROUTE" 2>/dev/null || true
    exit 1
fi
SCRIPT
chmod +x /usr/local/bin/vpn-connect

tee /usr/local/bin/vpn-disconnect >/dev/null <<SCRIPT
#!/bin/bash
if ! pgrep pppd > /dev/null 2>&1; then
    echo "No hay ninguna conexión VPN activa."
    notify-send -u low "VPN" "ℹ️ No hay VPN activa" 2>/dev/null || true
    exit 0
fi
sudo $KILLALL_BIN -9 pppd 2>/dev/null || true
sleep 1
echo "✔ VPN desconectada."
notify-send -u normal "VPN" "🔌 Desconectada" 2>/dev/null || true
SCRIPT
chmod +x /usr/local/bin/vpn-disconnect

tee /usr/local/bin/vpn-status >/dev/null <<SCRIPT
#!/bin/bash
if $IP_BIN link show ppp0 &>/dev/null && pgrep pppd > /dev/null 2>&1; then
    IP=\$($IP_BIN addr show ppp0 | grep 'inet ' | awk '{print \$2}')
    MSG="✔ VPN conectada — IP: \$IP"
else
    MSG="✘ VPN desconectada"
fi
echo "\$MSG"
notify-send "VPN Estado" "\$MSG" 2>/dev/null || true
SCRIPT
chmod +x /usr/local/bin/vpn-status
sep

# ════════════════════════════════════════════════════════════
#  SUDOERS PERMISIVO PARA LOS SCRIPTS
# ════════════════════════════════════════════════════════════
title "Configurando sudoers"
mkdir -p /etc/sudoers.d
tee /etc/sudoers.d/vpn-pptp >/dev/null <<EOF
$REAL_USER ALL=(ALL) NOPASSWD: $PPPD_BIN call *
$REAL_USER ALL=(ALL) NOPASSWD: $KILLALL_BIN -9 pppd
$REAL_USER ALL=(ALL) NOPASSWD: $KILLALL_BIN pppd
$REAL_USER ALL=(ALL) NOPASSWD: $IP_BIN route replace *
EOF
chmod 440 /etc/sudoers.d/vpn-pptp

# visudo valida la sintaxis. Si el fichero no parsea, sudo lo descarta entero
# junto con el resto de sudoers y el usuario se queda sin poder usar sudo, así
# que más vale abortar aquí que dejar el equipo en ese estado.
if command -v visudo >/dev/null && ! visudo -cf /etc/sudoers.d/vpn-pptp >/dev/null 2>&1; then
  error "El fichero de sudoers no es válido. Revísalo: /etc/sudoers.d/vpn-pptp"
fi
ok "Sudoers configurado sin contraseña para $REAL_USER."
sep

# ════════════════════════════════════════════════════════════
#  ARCHIVOS .desktop
# ════════════════════════════════════════════════════════════
title "Creando accesos directos (.desktop)"
DESKTOP_DIR="$REAL_HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"

tee "$DESKTOP_DIR/vpn-connect.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=VPN Conectar
Exec=/usr/local/bin/vpn-connect
Icon=network-vpn
Terminal=false
Type=Application
Categories=Network;
EOF

tee "$DESKTOP_DIR/vpn-disconnect.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=VPN Desconectar
Exec=/usr/local/bin/vpn-disconnect
Icon=network-vpn-disconnected
Terminal=false
Type=Application
Categories=Network;
EOF

tee "$DESKTOP_DIR/vpn-status.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=VPN Estado
Exec=/usr/local/bin/vpn-status
Icon=network-vpn-acquiring
Terminal=false
Type=Application
Categories=Network;
EOF

chown -R "$REAL_USER:$REAL_USER" "$DESKTOP_DIR" 2>/dev/null ||
  warn "No se pudo cambiar el propietario de $DESKTOP_DIR (revisar permisos)."
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
sep

# ════════════════════════════════════════════════════════════
#  KEYBINDS HYPRLAND
# ════════════════════════════════════════════════════════════
if [[ "$SETUP_KEYBINDS" == true ]]; then
  title "Configurando keybinds Hyprland"
  HYPR_VPN_CONF="$REAL_HOME/.config/hypr/vpn.conf"
  HYPR_MAIN="$REAL_HOME/.config/hypr/hyprland.conf"

  tee "$HYPR_VPN_CONF" >/dev/null <<EOF
bind = SUPER SHIFT, V, exec, /usr/local/bin/vpn-connect
bind = SUPER CTRL,  V, exec, /usr/local/bin/vpn-disconnect
bind = SUPER ALT,   V, exec, /usr/local/bin/vpn-status
EOF
  chown "$REAL_USER:$REAL_USER" "$HYPR_VPN_CONF" 2>/dev/null ||
    warn "No se pudo cambiar el propietario de $HYPR_VPN_CONF."

  if [[ -f "$HYPR_MAIN" ]] && ! grep -q "vpn.conf" "$HYPR_MAIN"; then
    echo -e "\nsource = ~/.config/hypr/vpn.conf" >>"$HYPR_MAIN"
  fi
  sep
fi

# ════════════════════════════════════════════════════════════
#  ALIASES
# ════════════════════════════════════════════════════════════
title "Agregando aliases de shell"
for RC in "$REAL_HOME/.bashrc" "$REAL_HOME/.zshrc"; do
  [[ -f "$RC" ]] || continue
  if ! grep -q "# VPN aliases" "$RC"; then
    tee -a "$RC" >/dev/null <<'ALIASES'

# VPN aliases
alias vpn-up='vpn-connect'
alias vpn-down='vpn-disconnect'
alias vpn-s='vpn-status'
ALIASES
  fi
done
sep

echo -e "\n${BOLD}${GREEN}✔ Instalación y parches aplicados exitosamente.${NC}"
