# mircl3-pptp.sh

Script Bash para instalación y configuración automática de VPN PPTP en Linux.

Compatible con:

- Arch Linux
- Manjaro
- Debian
- Ubuntu
- Derivados

---

# Características

- Detección automática de distribución Linux
- Instalación automática de dependencias PPTP
- Configuración automática de PPPD
- Creación de archivos peers y chap-secrets
- Configuración automática de rutas internas
- Scripts de conexión, desconexión y estado
- Integración opcional con Hyprland
- Creación de accesos directos `.desktop`
- Configuración de aliases de terminal
- Configuración automática de permisos sudoers

---

# Requisitos

- Linux basado en Arch o Debian
- Permisos sudo/root
- Acceso a servidor VPN PPTP

---

# Instalación

Clonar el repositorio:

```bash
git clone https://github.com/Miracl3nb/miracl3-pptp.git
cd miracl3-pptp
```

Dar permisos de ejecución:

```bash
chmod +x mircl3-pptp.sh
```

Ejecutar:

```bash
sudo bash mircl3-pptp.sh
```

---

# Datos solicitados por el script

Durante la ejecución se solicitarán:

- Nombre de conexión VPN
- Servidor VPN
- Usuario
- Contraseña
- Red interna a rutear

---

# Scripts creados

El instalador crea los siguientes scripts:

| Script | Función |
|---|---|
| vpn-connect | Conecta la VPN |
| vpn-disconnect | Desconecta la VPN |
| vpn-status | Verifica el estado |

Ubicación:

```bash
/usr/local/bin/
```

---

# Comandos rápidos

El script agrega aliases:

```bash
vpn-up
vpn-down
vpn-s
```

---

# Integración Hyprland

Si Hyprland es detectado, el script puede crear keybinds:

| Atajo | Acción |
|---|---|
| SUPER + SHIFT + V | Conectar VPN |
| SUPER + CTRL + V | Desconectar VPN |
| SUPER + ALT + V | Estado VPN |

---

# Archivos importantes

| Archivo | Función |
|---|---|
| /etc/ppp/peers/NOMBRE | Configuración VPN |
| /etc/ppp/chap-secrets | Credenciales |
| /etc/ppp/ip-up.d/vpn-route.sh | Ruta automática |
| /etc/ppp/ip-down.d/vpn-route.sh | Eliminación de ruta |
| /etc/sudoers.d/vpn-pptp | Permisos sudo |

---

# Desinstalación

Eliminar scripts:

```bash
sudo rm -f /usr/local/bin/vpn-connect
sudo rm -f /usr/local/bin/vpn-disconnect
sudo rm -f /usr/local/bin/vpn-status
```

Eliminar configuración PPP:

```bash
sudo rm -f /etc/ppp/peers/NOMBRE_VPN
```

Eliminar accesos directos:

```bash
rm -f ~/.local/share/applications/vpn-*.desktop
```

---

# Seguridad

El script:

- Restringe permisos de credenciales
- Configura sudoers únicamente para comandos VPN
- Realiza backups de configuraciones existentes

---

# Licencia

MIT License

---
