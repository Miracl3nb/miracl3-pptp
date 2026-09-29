# miracl3-pptp

Script Bash para instalación y configuración automática de VPN PPTP en Linux.

> [!IMPORTANT]
> Usa **`miracl3-pptp-debian.sh`**. El antiguo `mircl3-pptp.sh` está deprecado y
> ya no funciona: instalaba el hook de rutas como `vpn-route.sh`, nombre que
> `run-parts` descarta, así que la VPN conectaba pero la red interna quedaba sin
> ruta. Ya no hace nada y avisa de ello.

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
chmod +x miracl3-pptp-debian.sh
```

Ejecutar:

```bash
sudo bash miracl3-pptp-debian.sh
```

---

# Datos solicitados por el script

Durante la ejecución se solicitarán:

- Nombre de conexión VPN
- Servidor VPN
- Usuario
- Contraseña
- Red interna a rutear
- (Opcional) Usar los DNS del servidor VPN

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
| /etc/ppp/ip-up.d/10-vpnroute | Ruta automática + MTU interno |
| /etc/ppp/ip-down.d/10-vpnroute | Eliminación de ruta |
| /etc/ppp/ip-up, /etc/ppp/ip-down | Backup: `.bak` (el script añade un hook aquí) |
| /etc/sudoers.d/vpn-pptp | Permisos sudo |

> Los hooks de `ip-up.d` / `ip-down.d` van **sin extensión** y con prefijo
> numérico a propósito: en Debian/Ubuntu esos directorios se ejecutan con
> `run-parts`, que ignora cualquier archivo con extensión (`.sh` incluido).

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

# Troubleshooting

## ¿La VPN conecta pero no llego a los recursos internos?

Es el fallo más habitual, y **no es un problema de WiFi ni de PPTP**: el túnel
levanta correctamente (incluso `ping` al propio servidor PPTP responde) pero no
existe ruta hacia la red interna, así que todo lo demás se sale por tu router.

Comprueba primero a dónde se envía un destino interno:

```bash
ip route get 10.1.0.1
```

Si la respuesta termina en `via 192.168.0.1 dev wlo1` (o el nombre de tu
interfaz local) en vez de en `dev ppp0`, el problema es ese.

Comprueba si la ruta existe:

```bash
ip route show 10.1.0.0/16
```

### Causa raíz: `run-parts` ignora los hooks con extensión

`pppd` no ejecuta por sí solo los hooks de `/etc/ppp/ip-up.d`: los lanza
`/etc/ppp/ip-up` mediante `run-parts`, y **`run-parts` descarta cualquier archivo
con extensión o con punto** (`vpn-route.sh`, `vpn-route.old`, etc.). El hook se
instalaba pero no se ejecutaba nunca, sin ningún error visible.

Por eso el hook debe llamarse `10-vpnroute`, sin extensión. Compruébalo:

```bash
run-parts --test /etc/ppp/ip-up.d
```

Debe listar `10-vpnroute`. Si no aparece, renómbralo:

```bash
sudo mv /etc/ppp/ip-up.d/vpn-route.sh /etc/ppp/ip-up.d/10-vpnroute
sudo mv /etc/ppp/ip-down.d/vpn-route.sh /etc/ppp/ip-down.d/10-vpnroute
```

Para aplicarlo sin reconectar:

```bash
sudo ip route add 10.1.0.0/16 dev ppp0
```

### Qué hacer si `ip-up` no llama a `ip-up.d`

En Debian/Ubuntu el `/etc/ppp/ip-up` del paquete ya llama a `run-parts`, así que
no hay que tocarlo. En Arch, o en instalaciones antiguas, puede que no lo haga.
El instalador solo lo parchea si detecta que falta, y avisa con:

```bash
grep -n "ip-up.d" /etc/ppp/ip-up
```

Si no devuelve nada, añade al final de `/etc/ppp/ip-up`:

```sh
for file in /etc/ppp/ip-up.d/[0-9]*-vpnroute; do
  [ -x "$file" ] && "$file" "$@"
done
```

### Para depurar

Los hooks del instalador registran qué ocurre en cada conexión:

```bash
sudo tail -f /var/log/ppp-vpnroute.log
```

## ¿Es un problema usar WiFi en vez de cable?

No. PPTP se encapsula sobre IP (GRE dentro de PPP), así que funciona igual
sobre WiFi que sobre Ethernet. Si algo falla, la causa es de configuración
(rutas, DNS, MTU), no del enlace físico.

## Los sitios internos cargan a medias

Con MPPE el MTU efectivo del túnel baja a ~1396 bytes. El instalador ya limita
la MTU de la ruta interna a 1400; si aun así falla, baja ese valor en
`/etc/ppp/ip-up.d/10-vpnroute` a 1360 o 1300.

## No resuelvo los nombres de la empresa

El servidor VPN debe enviar los DNS correctos y hay que responder `s` a la
pregunta de DNS durante la instalación (equivale a `usepeerdns` en el peers
file). Comprueba con:

```bash
getent hosts servidor-interno
```

---

# Licencia

MIT License

---
