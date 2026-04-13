# Laboratorio endurecido

Guia completa del stack definido en `docker-compose.lab.yml`.

## Archivos utiles

- guia corta: `CHEATSHEET.md`
- diagrama: `assets/compose-diagram.svg`
- dashboard Grafana: `grafana/provisioning/dashboards/elusive-lab-overview.json`

## Resumen

El laboratorio incluye:

- segmentacion `edge`, `dmz`, `backend`
- `attacker`, `firewall`, `ips`
- `web`, `ldap`, `honeypot`, `proxy`
- `logs` + `grafana`
- `wazuh.manager`, `wazuh.indexer`, `wazuh.dashboard`
- agentes Wazuh sidecar
- defensa activa para SQLi repetido ejecutada en el firewall

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
- Honeypot Telnet: `172.31.0.40:2223`
- LDAP: `172.31.0.30:389`

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
- un agente adicional dedicado al firewall

## Flujo de deteccion y bloqueo

1. `attacker` genera trafico contra `web`, `honeypot` o `ldap`.
2. `lab-web-agent` detecta el SQLi en Apache.
3. Wazuh dispara la regla nativa `31103`.
4. Wazuh correlaciona con `100121`.
5. El agente del firewall ejecuta `firewall-drop`.
6. El `firewall` inserta reglas `DROP` reales en `iptables`.
7. Si se toca el honeytoken LDAP `SOC-admin`, Suricata dispara `100104`, Wazuh correlaciona `100131` y se bloquea la IP origen.
8. Si una IP genera una rafaga anomala de alertas IDS en poco tiempo, Wazuh dispara `100132` y bloquea preventivamente la fuente.

## Respuesta activa

- regla base: `31103`
- correlacion: `100121`
- umbral: 4 eventos en 60 segundos
- accion: `firewall-drop`
- timeout: 600 segundos
- regla base LDAP honeytoken: `100104`
- correlacion LDAP honeytoken: `100131`
- umbral LDAP honeytoken: 2 eventos en 120 segundos
- accion LDAP honeytoken: `firewall-drop`
- timeout LDAP honeytoken: 1800 segundos
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

### Honeypot Telnet

```powershell
docker exec -it elusive-lab-attacker-1 sh
nc -vz 172.31.0.40 2223
```

### LDAP

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

Simular toque de honeytoken (debe generar alerta + bloqueo activo):

```powershell
docker exec -it elusive-lab-attacker-1 sh
for i in 1 2; do
  echo "cn=SOC-admin,ou=tokens,dc=elusive,dc=lab" | nc -w1 172.31.0.30 389 >/dev/null
done
```

### Activar defensa activa por anomalia IDS

Genera una rafaga de eventos en servicios DMZ para disparar la correlacion `100132`:

```powershell
docker exec -it elusive-lab-attacker-1 sh
for i in 1 2 3; do
  curl -s "http://172.31.0.20/vulnerabilities/sqli/?id=1%20union%20select%201,2&Submit=Submit" >/dev/null
  nc -w1 172.31.0.30 389 </dev/null >/dev/null
  nc -w1 172.31.0.40 2223 </dev/null >/dev/null
done
```

## Verificar el bloqueo

En Wazuh:

- busca la `100121`
- busca la `100131`
- busca la `100132`
- busca el evento `651` de `firewall-drop`

En terminal:

```powershell
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
- bootstrap LDAP: `ldap/bootstrap/10-tokens.ldif`
- Firewall: `firewall/init.sh`
- Dashboard: `grafana/provisioning/dashboards/elusive-lab-overview.json`
