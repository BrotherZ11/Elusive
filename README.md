# SOC

SOC para la asignatura de Ciberinteligencia y Ciberdefensa del Máster Universitario en Ciberseguridad de la Universidad de Málaga.

## Material rapido

- guia corta: `CHEATSHEET.md`
- guia detallada: `LAB-README.md`
- diagrama del stack: `assets/compose-diagram.svg`

## Componentes

- `edge`: `nat1`, `attacker`, `firewall`
- `dmz`: `web`, `ldap`, `honeypot`, `proxy`, `ips`
- `backend`: `logs`, `grafana`, `agenteia`, `database`, `wazuh.*`
- agentes Wazuh sidecar: `lab-web-agent`, `lab-honeypot-agent`, `lab-proxy-agent`, `lab-ips-agent`, `lab-agenteia-agent`, `lab-ldap-agent` y el agente del firewall

## Arranque

Generar certificados si faltan:

```powershell
docker compose -f generate-indexer-certs.yml run --rm generator
```

Levantar el laboratorio:

```powershell
docker compose -f docker-compose.lab.yml up -d
```

Comprobar estado:

```powershell
docker compose -f docker-compose.lab.yml ps
```

## Accesos

- DVWA: `http://localhost:8088`
- Wazuh: `http://localhost:5602`
- Grafana: `http://localhost:3001`
- AgenteIA: `http://localhost:8001`
- Honeypot SSH: `localhost:2225`
- Honeypot Telnet: `localhost:2226`

Credenciales:

- Wazuh: `admin / SecretPassword`
- Grafana: `admin / SecretPassword`
- LDAP: `cn=admin,dc=elusive,dc=lab / admin123`

## Flujo de defensa activa

1. El ataque sale desde `attacker`.
2. `lab-web-agent` detecta el SQLi.
3. Wazuh dispara la correlacion `100121`.
4. El agente del firewall ejecuta `firewall-drop`.
5. El `firewall` inserta reglas `DROP` para la IP atacante.
6. Si se toca el honeytoken LDAP `SOC-admin`, se activa otra correlacion y bloqueo preventivo.
7. Si Cowrie observa multiples fallos SSH, se activa la correlacion `100133` y bloqueo automatico.
8. Si Cowrie observa una rafaga de conexiones SSH, se activa la correlacion `100134` y bloqueo automatico.
9. Si Cowrie registra un login exitoso en el honeypot, se activa la correlacion `100135` y bloqueo automatico.
10. Si una IP muestra un patron anomalo (rafaga IDS), se activa correlacion `100132` y bloqueo automatico.

## Estructura relevante

- `docker-compose.lab.yml`: stack alternativo completo
- `CHEATSHEET.md`: comandos de arranque y pruebas
- `LAB-README.md`: guia completa del laboratorio
- `assets/compose-diagram.svg`: diagrama editable
- `firewall/init.sh`: reglas base del firewall
- `ips/suricata.yaml`: configuracion IDS
- `ips/rules/local.rules`: reglas del laboratorio
- `fluent-bit/fluent-bit.conf`: envio de logs a Loki
- `grafana/provisioning`: datasource y dashboard
- `agents/*.conf`: sidecars Wazuh
- `wazuh/local_rules.xml`: reglas Wazuh del laboratorio

## Nota

Para validar bloqueo por IP de forma realista, los ataques deben salir desde `attacker`, no desde `localhost`.
