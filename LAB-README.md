# Laboratorio endurecido

Guia completa del stack definido en `docker-compose.lab.yml`.

## Archivos utiles

- guia corta: `CHEATSHEET.md`
- diagrama: `assets/compose-diagram.svg`
- dashboard Grafana: `grafana/provisioning/dashboards/elusive-lab-overview.json`

## Resumen

El laboratorio incluye:

- segmentacion `edge`, `dmz`, `backend`, `internal`
- `attacker`, `firewall`, `ips`
- `web`, `ldap`, `honeypot`, `proxy`
- endpoints internos simulados: `endpoint.workstation`, `endpoint.mobile01`, `endpoint.mobile02`
- `logs` + `grafana`
- `wazuh.manager`, `wazuh.indexer`, `wazuh.dashboard`
- agentes Wazuh sidecar
- defensa activa para SQLi repetido, honeytoken LDAP y fuerza bruta SSH ejecutada en el firewall

## Como acceder

Desde Windows:

- DVWA: `http://localhost:8088`
- Wazuh: `http://localhost:5602`
- Grafana: `http://localhost:3001`
- AgenteIA: `http://localhost:8001`

No uses `http://172.31.0.20` desde Windows. Esa IP pertenece a la red Docker `dmz`.

Desde `attacker`:

- DVWA: `http://172.31.0.20`
- Honeypot SSH: `172.31.0.40:2222`
- LDAP: `172.31.0.30:389`
- credencial conocida del honeypot SSH: `root` con password vacia

Entrar al atacante:

```powershell
docker exec -it elusive-lab-attacker-1 sh
```

## Agentes esperados en Wazuh

- `lab-web-agent`
- `lab-honeypot-agent`
- `lab-proxy-agent`
- `lab-ips-agent`
- `lab-agenteia-agent`
- `lab-firewall-agent`
- `lab-ldap-agent`
- `lab-endpoint-workstation-agent`
- `lab-endpoint-mobile01-agent`
- `lab-endpoint-mobile02-agent`

Los tres endpoints internos actuan como equipos de trabajo (PC y moviles) y envian telemetria de actividad mediante su agente XDR (Wazuh) leyendo `/var/log/endpoint/activity.log`.

## Flujo de deteccion y bloqueo

1. `attacker` genera trafico contra `web`, `honeypot` o `ldap`.
2. `lab-web-agent` detecta el SQLi en Apache.
3. Wazuh dispara la regla nativa `31103`.
4. Wazuh correlaciona con `100121`.
5. El agente del firewall ejecuta `firewall-drop`.
6. El `firewall` inserta reglas `DROP` reales en `iptables`.
7. Si se consulta el honeytoken LDAP `SOC-admin`, `lab-ldap-agent` registra el evento JSON, Wazuh dispara `100105`, correlaciona `100131` y bloquea la IP origen en el firewall.
8. Si Cowrie observa multiples fallos de login SSH desde la misma IP, Wazuh dispara `100106`, correlaciona `100133` y bloquea la fuente en el firewall.
9. Si Cowrie observa una rafaga de conexiones SSH contra el honeypot, Wazuh dispara `100108`, correlaciona `100134` y bloquea la IP aunque no llegue a ver contraseñas.
10. Si Cowrie registra un login exitoso en el honeypot, Wazuh dispara `100107`, correlaciona `100135` y bloquea la IP de inmediato.
11. Si una IP genera una rafaga anomala de alertas IDS en poco tiempo, Wazuh dispara `100132` y bloquea preventivamente la fuente.

## Respuesta activa

- regla base: `31103`
- correlacion: `100121`
- umbral: 4 eventos en 60 segundos
- accion: `firewall-drop`
- timeout: 600 segundos
- regla base LDAP honeytoken: `100105`
- correlacion LDAP honeytoken: `100131`
- umbral LDAP honeytoken: 2 eventos en 120 segundos
- accion LDAP honeytoken: `firewall-drop`
- timeout LDAP honeytoken: 1800 segundos
- regla base SSH brute force honeypot: `100106`
- correlacion SSH brute force honeypot: `100133`
- umbral SSH brute force honeypot: 4 fallos en 120 segundos
- accion SSH brute force honeypot: `firewall-drop`
- timeout SSH brute force honeypot: 1200 segundos
- regla base SSH connection burst honeypot: `100108`
- correlacion SSH connection burst honeypot: `100134`
- umbral SSH connection burst honeypot: 6 conexiones en 120 segundos
- accion SSH connection burst honeypot: `firewall-drop`
- timeout SSH connection burst honeypot: 900 segundos
- regla base SSH login success honeypot: `100107`
- correlacion SSH login success honeypot: `100135`
- umbral SSH login success honeypot: 1 evento
- accion SSH login success honeypot: `firewall-drop`
- timeout SSH login success honeypot: 1800 segundos
- regla de anomalia IDS: `100132`
- umbral anomalia IDS: 6 alertas Suricata en 90 segundos (misma IP)
- accion anomalia IDS: `firewall-drop`
- timeout anomalia IDS: 900 segundos

## Identidad fija del agente del firewall

El laboratorio usa `client.keys` estatico para que `lab-firewall-agent` conserve siempre el ID `003`.
No hace falta reajustar `<agent_id>` en cada despliegue.

Si quieres verificarlo:

```powershell
docker exec elusive-lab-wazuh.manager-1 /var/ossec/bin/agent_control -l
```

## Pruebas recomendadas

### Trafico web normal

```powershell
curl http://localhost:8088/
```

### SQLi desde attacker

```powershell
docker exec -it elusive-lab-attacker-1 sh
curl "http://172.31.0.20/vulnerabilities/sqli/?id=1%20union%20select%201,2&Submit=Submit"
```

### Activar el bloqueo

```sh
for i in 1 2 3 4 5; do
  curl -s "http://172.31.0.20/vulnerabilities/sqli/?id=1%20union%20select%201,2&Submit=Submit" >/dev/null
  sleep 1
done
```

### Honeypot SSH

```powershell
docker exec -it elusive-lab-attacker-1 sh
ssh admin@172.31.0.40 -p 2222
```

### Bloqueo SSH por fallos de login

Instalar `sshpass` en `attacker` si hace falta:

```powershell
docker exec -it elusive-lab-attacker-1 sh
apk add --no-cache sshpass
```

Simular fuerza bruta SSH (debe generar `100106`, correlacion `100133` y bloqueo activo):

```sh
for i in 1 2 3 4; do
  sshpass -p wrongpass ssh -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -p 2222 admin@172.31.0.40 exit >/dev/null 2>&1 || true
  sleep 1
done
```

### Bloqueo SSH por rafaga de conexiones

Simular una rafaga de conexiones SSH sin autenticar (debe generar `100108`, correlacion `100134` y bloqueo activo):

```sh
for i in 1 2 3 4 5 6; do
  nc -vz 172.31.0.40 2222 >/dev/null 2>&1
  sleep 1
done
```

### Bloqueo SSH por login exitoso

Un login exitoso en el honeypot tambien bloquea la IP (debe generar `100107`, correlacion `100135` y bloqueo activo):

Credencial conocida del honeypot:

- usuario: `root`
- password: vacia, pulsa `Enter`

```sh
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 root@172.31.0.40
```

### LDAP basico

```powershell
docker exec -it elusive-lab-attacker-1 sh
nc -vz 172.31.0.30 389
```

### Tokens LDAP y honeytoken

El LDAP se inicializa con entradas en `ou=tokens,dc=elusive,dc=lab`:

- `cn=svc-monitoring` (token operacional)
- `cn=svc-backup` (token operacional)
- `cn=SOC-admin` (**honeytoken**, no debe usarse en flujos legitimos)

Verificar desde el contenedor LDAP:

```powershell
docker exec -it elusive-lab-ldap-1 ldapsearch -x -H ldap://localhost:389 -D "cn=admin,dc=elusive,dc=lab" -w admin123 -b "ou=tokens,dc=elusive,dc=lab" "(objectClass=inetOrgPerson)" cn description
```

Instalar cliente LDAP en `attacker` si hace falta:

```powershell
docker exec -it elusive-lab-attacker-1 sh
apk add --no-cache openldap-clients
```

Consulta simple al honeytoken:

```sh
ldapsearch -x -H ldap://172.31.0.30:389 -D "cn=admin,dc=elusive,dc=lab" -w admin123 -b "ou=tokens,dc=elusive,dc=lab" "(cn=SOC-admin)" cn
```

Simular ataque al honeytoken (debe generar alerta `100105`, correlacion `100131` y bloqueo activo):

```sh
for i in 1 2; do
  ldapsearch -x -H ldap://172.31.0.30:389 -D "cn=admin,dc=elusive,dc=lab" -w admin123 -b "ou=tokens,dc=elusive,dc=lab" "(cn=SOC-admin)" cn >/dev/null
  sleep 1
done
```

### Activar defensa activa por anomalia IDS

Genera una rafaga de eventos en servicios DMZ para disparar la correlacion `100132`:

```powershell
docker exec -it elusive-lab-attacker-1 sh
for i in 1 2 3; do
  curl -s "http://172.31.0.20/vulnerabilities/sqli/?id=1%20union%20select%201,2&Submit=Submit" >/dev/null
  nc -w1 172.31.0.30 389 </dev/null >/dev/null
done
```

## Verificar el bloqueo

En Wazuh:

- busca la `100121`
- busca la `100105`
- busca la `100106`
- busca la `100107`
- busca la `100108`
- busca la `100131`
- busca la `100133`
- busca la `100134`
- busca la `100135`
- busca la `100132`
- busca el evento `651` de `firewall-drop`

En terminal:

```powershell
docker exec elusive-lab-wazuh.manager-1 sh -c "grep '100105\|100131\|100106\|100133\|100108\|100134\|100107\|100135\|firewall-drop' /var/ossec/logs/alerts/alerts.json | tail -n 40"
docker exec elusive-lab-firewall.agent-1 sh -c "tail -n 80 /var/ossec/logs/active-responses.log"
docker exec elusive-lab-firewall-1 sh -c "iptables -S"
```

Reglas esperadas:

```text
-A INPUT -s 172.30.0.20/32 -j DROP
-A FORWARD -s 172.30.0.20/32 -j DROP
```

## Quitar el bloqueo manualmente

```powershell
docker exec elusive-lab-firewall-1 sh -c "iptables -D INPUT -s 172.30.0.20 -j DROP; iptables -D FORWARD -s 172.30.0.20 -j DROP"
docker exec elusive-lab-firewall-1 sh -c "iptables -S"
```

## Grafana

- URL: `http://localhost:3001`
- usuario: `admin`
- password: `SecretPassword`
- dashboard: `Elusive Lab Overview`

Consultas utiles en Explore:

```logql
{job="dmz-forwarder", tag="dmz.web"}
```

```logql
{job="dmz-forwarder", tag="dmz.ips"}
```

```logql
{job="dmz-forwarder", tag="dmz.honeypot"}
```

```logql
{job="dmz-forwarder", tag="dmz.proxy"}
```

## Logs directos

```powershell
docker exec -it elusive-lab-ips-1 sh -c "tail -n 20 /var/log/suricata/eve.json"
docker exec -it elusive-lab-proxy-1 sh -c "tail -n 20 /var/log/nginx/access.log"
docker exec -it elusive-lab-honeypot-1 sh -c "tail -n 20 /cowrie/cowrie-git/var/log/cowrie/cowrie.json"
docker exec -it elusive-lab-firewall.agent-1 sh -c "tail -n 20 /var/ossec/logs/active-responses.log"
docker exec -it elusive-lab-firewall-1 sh -c "iptables -S"
```

## Troubleshooting

### Agentes desconectados

```powershell
docker compose -f docker-compose.lab.yml up -d --force-recreate web.agent honeypot.agent proxy.agent ips.agent agenteia.agent firewall.agent
```

### Rehacer el stack

```powershell
docker compose -f docker-compose.lab.yml down -v
docker compose -f docker-compose.lab.yml up -d
```

### Reglas y ficheros clave

- Suricata: `ips/rules/local.rules`
- Wazuh: `wazuh/local_rules.xml`
- decoder local: `wazuh/local_decoder.xml`
- bootstrap LDAP: `ldap/bootstrap/10-tokens.ldif`
- wrapper LDAP honeytoken: `ldap/start.sh`
- agente LDAP: `agents/ldap-agent.conf`
- wrapper honeypot agent: `honeypot-agent/start.sh`
- agente honeypot: `agents/honeypot-agent.conf`
- Firewall: `firewall/init.sh`
- Dashboard: `grafana/provisioning/dashboards/elusive-lab-overview.json`
