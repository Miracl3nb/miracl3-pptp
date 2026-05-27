#!/bin/bash
# ================================================================
#  mircl3-pptp.sh
#  Instalación y configuración completa de VPN PPTP
#  Soporta: Arch, Manjaro, Debian, Ubuntu y derivados
#  Uso: sudo bash mircl3-pptp.sh
# ================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()      { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERR ]${NC} $1"; exit 1; }
sep()     { echo -e "${BOLD}────────────────────────────────────────────${NC}"; }
title()   { echo -e "\n${BOLD}${CYAN}  ▸ $1${NC}\n"; }
ask()     { echo -e "${YELLOW}[?]${NC} $1"; }

# ── Root check ───────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Ejecutar como root: sudo bash $0"

REAL_USER="${SUDO_USER:-$USER}"
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
    elif [[ "$DISTRO_ID" == "debian" || "$DISTRO_LIKE" == *"debian"* || \
            "$DISTRO_ID" == "ubuntu" || "$DISTRO_LIKE" == *"ubuntu"* ]]; then
        DISTRO_FAMILY="debian"
    else
        error "Distro no soportada: $DISTRO_ID. Soportadas: Arch, Manjaro, Debian, Ubuntu y derivados."
    fi
}

# ── Detectar Hyprland ────────────────────────────────────────
detect_hyprland() {
    HYPRLAND=false
    HYPR_DIR="$REAL_HOME/.config/hypr"
    if [[ -d "$HYPR_DIR" ]] || command -v Hyprland &>/dev/null || \
       [[ "${XDG_CURRENT_DESKTOP,,}" == *"hyprland"* ]] || \
       [[ "${XDG_SESSION_DESKTOP,,}" == *"hyprland"* ]]; then
        HYPRLAND=true
    fi
}


# ── Detectar UFW ─────────────────────────────────────────────
detect_ufw() {
    UFW_ACTIVE=false
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        UFW_ACTIVE=true
    fi
}

# ── Instalar paquetes ────────────────────────────────────────
install_packages() {
    title "Instalando dependencias"
    case "$DISTRO_FAMILY" in
        arch)
            info "Actualizando base de datos pacman..."
            pacman -Sy --noconfirm > /dev/null 2>&1
            for pkg in pptpclient networkmanager-pptp; do
                if pacman -Qi "$pkg" &>/dev/null; then
                    warn "$pkg ya instalado."
                else
                    info "Instalando $pkg..."
                    pacman -S --noconfirm "$pkg" > /dev/null 2>&1 && ok "$pkg instalado."
                fi
            done
            ;;
        debian)
            info "Actualizando lista apt..."
            apt-get update -qq > /dev/null 2>&1
            for pkg in pptp-linux network-manager-pptp network-manager-pptp-gnome; do
                if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
                    warn "$pkg ya instalado."
                else
                    info "Instalando $pkg..."
                    apt-get install -y -qq "$pkg" > /dev/null 2>&1 && ok "$pkg instalado."
                fi
            done
            ;;
    esac
}

# ════════════════════════════════════════════════════════════
#  BANNER
# ════════════════════════════════════════════════════════════
clear
echo -e "${BOLD}${CYAN}"
echo "  ██╗   ██╗██████╗ ███╗   ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗ "
echo "  ██║   ██║██╔══██╗████╗  ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗"
echo "  ██║   ██║██████╔╝██╔██╗ ██║    ███████╗█████╗     ██║   ██║   ██║██████╔╝"
echo "  ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ "
echo "   ╚████╔╝ ██║     ██║ ╚████║    ███████║███████╗   ██║   ╚██████╔╝██║     "
echo "    ╚═══╝  ╚═╝     ╚═╝  ╚═══╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     "
echo -e "${NC}"
echo -e "  ${BOLD}Configurador de VPN PPTP — Multi-distro${NC}"
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

read -p "  Nombre de la conexión (ej: vpn-oficina):           " VPN_NAME
[[ -z "$VPN_NAME" ]] && error "El nombre no puede estar vacío."

read -p "  Servidor VPN (ej: vpn.empresa.net):           " VPN_SERVER
[[ -z "$VPN_SERVER" ]] && error "El servidor no puede estar vacío."

read -p "  Usuario (ej: usuario@dominio.com):            " VPN_USER
[[ -z "$VPN_USER" ]] && error "El usuario no puede estar vacío."

read -s -p "  Contraseña:                                   " VPN_PASS
echo ""
[[ -z "$VPN_PASS" ]] && error "La contraseña no puede estar vacía."

read -p "  Red interna a rutear (ej: 10.1.0.0/16):      " VPN_ROUTE
[[ -z "$VPN_ROUTE" ]] && error "La red no puede estar vacía."

# ── Preguntar keybinds si hay Hyprland ───────────────────────
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

[[ -f "$PEERS_FILE" ]] && {
    warn "Ya existe $PEERS_FILE — backup en ${PEERS_FILE}.bak"
    cp "$PEERS_FILE" "${PEERS_FILE}.bak"
}

tee "$PEERS_FILE" > /dev/null << EOF
pty "pptp $VPN_SERVER --nolaunchpppd"
name $VPN_USER
remotename PPTP
require-mppe-128
require-mschap-v2
noauth
nobsdcomp
nodeflate
noipdefault
defaultroute
maxfail 1
holdoff 5
EOF
ok "Archivo de peers creado: $PEERS_FILE"

touch "$CHAP_FILE"
chmod 600 "$CHAP_FILE"
sed -i "/^${VPN_USER//\//\\/}[[:space:]]*PPTP/d" "$CHAP_FILE"
echo "$VPN_USER PPTP $VPN_PASS *" >> "$CHAP_FILE"
ok "Credenciales guardadas: $CHAP_FILE"

# ════════════════════════════════════════════════════════════
#  RUTAS AUTOMÁTICAS ip-up.d / ip-down.d
# ════════════════════════════════════════════════════════════
title "Configurando rutas automáticas"

mkdir -p /etc/ppp/ip-up.d /etc/ppp/ip-down.d

tee /etc/ppp/ip-up.d/vpn-route.sh > /dev/null << EOF
#!/bin/bash
ip route add $VPN_ROUTE dev ppp0 2>/dev/null || true
EOF
chmod +x /etc/ppp/ip-up.d/vpn-route.sh
ok "ip-up.d/vpn-route.sh — ruta $VPN_ROUTE se agrega al conectar."

tee /etc/ppp/ip-down.d/vpn-route.sh > /dev/null << EOF
#!/bin/bash
ip route del $VPN_ROUTE dev ppp0 2>/dev/null || true
EOF
chmod +x /etc/ppp/ip-down.d/vpn-route.sh
ok "ip-down.d/vpn-route.sh — ruta $VPN_ROUTE se elimina al desconectar."

# Verificar que /etc/ppp/ip-up llama a ip-up.d/*.sh
if [[ -f /etc/ppp/ip-up ]]; then
    if ! grep -q "ip-up.d" /etc/ppp/ip-up; then
        warn "/etc/ppp/ip-up no llama a ip-up.d — agregando..."
        tee -a /etc/ppp/ip-up > /dev/null << 'IPUP'
for ipup in /etc/ppp/ip-up.d/*.sh; do
  [ -x "$ipup" ] && "$ipup" "$@"
done
IPUP
        ok "/etc/ppp/ip-up actualizado."
    fi
else
    tee /etc/ppp/ip-up > /dev/null << 'IPUP'
#!/bin/sh
for ipup in /etc/ppp/ip-up.d/*.sh; do
  [ -x "$ipup" ] && "$ipup" "$@"
done
IPUP
    chmod +x /etc/ppp/ip-up
    ok "/etc/ppp/ip-up creado."
fi

# Verificar ip-down
if [[ -f /etc/ppp/ip-down ]]; then
    if ! grep -q "ip-down.d" /etc/ppp/ip-down; then
        tee -a /etc/ppp/ip-down > /dev/null << 'IPDOWN'
for ipdown in /etc/ppp/ip-down.d/*.sh; do
  [ -x "$ipdown" ] && "$ipdown" "$@"
done
IPDOWN
        ok "/etc/ppp/ip-down actualizado."
    fi
else
    tee /etc/ppp/ip-down > /dev/null << 'IPDOWN'
#!/bin/sh
for ipdown in /etc/ppp/ip-down.d/*.sh; do
  [ -x "$ipdown" ] && "$ipdown" "$@"
done
IPDOWN
    chmod +x /etc/ppp/ip-down
    ok "/etc/ppp/ip-down creado."
fi

sep

# ════════════════════════════════════════════════════════════
#  BINARIOS
# ════════════════════════════════════════════════════════════
PPPD_BIN=$(which pppd 2>/dev/null || echo "/usr/sbin/pppd")
KILLALL_BIN=$(which killall 2>/dev/null || echo "/usr/bin/killall")
IP_BIN=$(which ip 2>/dev/null || echo "/usr/sbin/ip")

# ════════════════════════════════════════════════════════════
#  SCRIPTS DE CONTROL
# ════════════════════════════════════════════════════════════
title "Creando scripts de control"

# ── vpn-connect ──────────────────────────────────────────────
tee /usr/local/bin/vpn-connect > /dev/null << SCRIPT
#!/bin/bash
VPN_NAME="$VPN_NAME"

if pgrep pppd > /dev/null 2>&1; then
    echo "Limpiando conexiones pppd previas..."
    $KILLALL_BIN -9 pppd 2>/dev/null || true
    sleep 2
fi

echo "Conectando \$VPN_NAME..."
$PPPD_BIN call "\$VPN_NAME"

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
echo "✔ VPN conectada — IP: \$IP_LOCAL"
notify-send -u normal "VPN" "✅ Conectada — \$IP_LOCAL" 2>/dev/null || true
SCRIPT
chmod +x /usr/local/bin/vpn-connect
ok "vpn-connect → /usr/local/bin/vpn-connect"

# ── vpn-disconnect ───────────────────────────────────────────
tee /usr/local/bin/vpn-disconnect > /dev/null << SCRIPT
#!/bin/bash
if ! pgrep pppd > /dev/null 2>&1; then
    echo "No hay ninguna conexión VPN activa."
    notify-send -u low "VPN" "ℹ️ No hay VPN activa" 2>/dev/null || true
    exit 0
fi
$KILLALL_BIN -9 pppd 2>/dev/null || true
sleep 1
echo "✔ VPN desconectada."
notify-send -u normal "VPN" "🔌 Desconectada" 2>/dev/null || true
SCRIPT
chmod +x /usr/local/bin/vpn-disconnect
ok "vpn-disconnect → /usr/local/bin/vpn-disconnect"

# ── vpn-status ───────────────────────────────────────────────
tee /usr/local/bin/vpn-status > /dev/null << SCRIPT
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
ok "vpn-status → /usr/local/bin/vpn-status"

sep

# ════════════════════════════════════════════════════════════
#  SUDOERS
# ════════════════════════════════════════════════════════════
title "Configurando sudoers"
tee /etc/sudoers.d/vpn-pptp > /dev/null << EOF
# VPN PPTP — sin contraseña para comandos de red
$REAL_USER ALL=(ALL) NOPASSWD: $PPPD_BIN call $VPN_NAME
$REAL_USER ALL=(ALL) NOPASSWD: $KILLALL_BIN -9 pppd
$REAL_USER ALL=(ALL) NOPASSWD: $KILLALL_BIN pppd
EOF
chmod 440 /etc/sudoers.d/vpn-pptp
ok "Sudoers configurado: /etc/sudoers.d/vpn-pptp"
sep

# ════════════════════════════════════════════════════════════
#  ARCHIVOS .desktop
# ════════════════════════════════════════════════════════════
title "Creando accesos directos (.desktop)"

DESKTOP_DIR="$REAL_HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"

tee "$DESKTOP_DIR/vpn-connect.desktop" > /dev/null << EOF
[Desktop Entry]
Name=VPN Conectar
Comment=Conectar a la VPN corporativa ($VPN_SERVER)
Exec=/usr/local/bin/vpn-connect
Icon=network-vpn
Terminal=false
Type=Application
Categories=Network;
Keywords=vpn;conectar;red;pptp;
EOF
ok "vpn-connect.desktop → $DESKTOP_DIR"

tee "$DESKTOP_DIR/vpn-disconnect.desktop" > /dev/null << EOF
[Desktop Entry]
Name=VPN Desconectar
Comment=Desconectar la VPN corporativa
Exec=/usr/local/bin/vpn-disconnect
Icon=network-vpn-disconnected
Terminal=false
Type=Application
Categories=Network;
Keywords=vpn;desconectar;red;pptp;
EOF
ok "vpn-disconnect.desktop → $DESKTOP_DIR"

tee "$DESKTOP_DIR/vpn-status.desktop" > /dev/null << EOF
[Desktop Entry]
Name=VPN Estado
Comment=Ver el estado actual de la VPN
Exec=/usr/local/bin/vpn-status
Icon=network-vpn-acquiring
Terminal=false
Type=Application
Categories=Network;
Keywords=vpn;estado;status;red;
EOF
ok "vpn-status.desktop → $DESKTOP_DIR"

chown -R "$REAL_USER:$REAL_USER" "$DESKTOP_DIR"
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
ok "Base de aplicaciones actualizada."
sep

# ════════════════════════════════════════════════════════════
#  KEYBINDS HYPRLAND (opcional)
# ════════════════════════════════════════════════════════════
if [[ "$SETUP_KEYBINDS" == true ]]; then
    title "Configurando keybinds Hyprland"
    HYPR_VPN_CONF="$REAL_HOME/.config/hypr/vpn.conf"
    HYPR_MAIN="$REAL_HOME/.config/hypr/hyprland.conf"

    tee "$HYPR_VPN_CONF" > /dev/null << EOF
# ── VPN keybinds ─────────────────────────────────────────────
# SUPER + SHIFT + V  →  Conectar VPN
# SUPER + CTRL  + V  →  Desconectar VPN
# SUPER + ALT   + V  →  Estado VPN

bind = SUPER SHIFT, V, exec, /usr/local/bin/vpn-connect
bind = SUPER CTRL,  V, exec, /usr/local/bin/vpn-disconnect
bind = SUPER ALT,   V, exec, /usr/local/bin/vpn-status
EOF
    chown "$REAL_USER:$REAL_USER" "$HYPR_VPN_CONF"
    ok "vpn.conf creado: $HYPR_VPN_CONF"

    if [[ -f "$HYPR_MAIN" ]] && ! grep -q "vpn.conf" "$HYPR_MAIN"; then
        echo "" >> "$HYPR_MAIN"
        echo "source = ~/.config/hypr/vpn.conf" >> "$HYPR_MAIN"
        ok "vpn.conf incluido en hyprland.conf."
    elif [[ ! -f "$HYPR_MAIN" ]]; then
        warn "hyprland.conf no encontrado. Agregá manualmente:"
        echo "      source = ~/.config/hypr/vpn.conf"
    else
        warn "vpn.conf ya estaba incluido en hyprland.conf."
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
        tee -a "$RC" > /dev/null << 'ALIASES'

# VPN aliases
alias vpn-up='vpn-connect'
alias vpn-down='vpn-disconnect'
alias vpn-s='vpn-status'
ALIASES
        ok "Aliases agregados en $RC."
    else
        warn "Aliases ya presentes en $RC."
    fi
done
sep

# ════════════════════════════════════════════════════════════
#  RESUMEN FINAL
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}  ✔ Instalación completada exitosamente${NC}"
echo ""
echo -e "  ${BOLD}Configuración aplicada:${NC}"
echo -e "  • Distro      : ${CYAN}${PRETTY_NAME}${NC}"
echo -e "  • Servidor    : ${CYAN}$VPN_SERVER${NC}"
echo -e "  • Usuario     : ${CYAN}$VPN_USER${NC}"
echo -e "  • Red interna : ${CYAN}$VPN_ROUTE${NC} (automática vía ip-up.d)"
echo -e "  • Protocolo   : ${CYAN}PPTP + EAP/MSCHAPv2 + MPPE-128${NC}"
echo ""
echo -e "  ${BOLD}Cómo usar:${NC}"
echo -e "  Terminal  →  ${YELLOW}vpn-up${NC} / ${YELLOW}vpn-down${NC} / ${YELLOW}vpn-s${NC}"
echo -e "  Lanzador  →  Buscar ${YELLOW}VPN Conectar${NC} / ${YELLOW}VPN Desconectar${NC} / ${YELLOW}VPN Estado${NC}"
if [[ "$SETUP_KEYBINDS" == true ]]; then
echo -e "  Hyprland  →  ${YELLOW}SUPER+SHIFT+V${NC} / ${YELLOW}SUPER+CTRL+V${NC} / ${YELLOW}SUPER+ALT+V${NC}"
fi
echo ""
sep
echo -e "\n  ${BOLD}${YELLOW}  ► Archivos a modificar si cambian los datos de conexión:${NC}\n"
echo -e "  ${BOLD}Contraseña:${NC}"
echo -e "  → ${CYAN}/etc/ppp/chap-secrets${NC}"
echo -e "     Formato: ${YELLOW}$VPN_USER PPTP NUEVA_CONTRASEÑA *${NC}"
echo ""
echo -e "  ${BOLD}Servidor / Usuario:${NC}"
echo -e "  → ${CYAN}/etc/ppp/peers/$VPN_NAME${NC}"
echo -e "     Campos: ${YELLOW}pty${NC} (servidor) y ${YELLOW}name${NC} (usuario)"
echo ""
echo -e "  ${BOLD}Red interna (ruta):${NC}"
echo -e "  → ${CYAN}/etc/ppp/ip-up.d/vpn-route.sh${NC}"
echo -e "  → ${CYAN}/etc/ppp/ip-down.d/vpn-route.sh${NC}"
echo -e "     Cambiar la IP/máscara en ambos archivos."
echo ""
echo -e "  ${BOLD}Scripts de control:${NC}"
echo -e "  → ${CYAN}/usr/local/bin/vpn-connect${NC}"
echo -e "  → ${CYAN}/usr/local/bin/vpn-disconnect${NC}"
echo -e "  → ${CYAN}/usr/local/bin/vpn-status${NC}"
echo ""
if [[ "$SETUP_KEYBINDS" == true ]]; then
echo -e "  ${BOLD}Keybinds Hyprland:${NC}"
echo -e "  → ${CYAN}$REAL_HOME/.config/hypr/vpn.conf${NC}"
echo ""
fi
echo -e "  ${BOLD}Permisos sudo:${NC}"
echo -e "  → ${CYAN}/etc/sudoers.d/vpn-pptp${NC}"
echo ""
echo -e "  Recargá el shell: ${YELLOW}source ~/.zshrc${NC}  o  ${YELLOW}source ~/.bashrc${NC}"
echo ""
