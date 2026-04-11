# Topologia alternativa endurecida

Este stack reproduce el esquema de red del diagrama sin reemplazar el `docker-compose.yml` original. Se ha preparado como un segundo entorno, con segmentacion por zonas, forwarding centralizado de logs de la DMZ y reglas iniciales de deteccion para pruebas de laboratorio.

## Objetivo del entorno

La topologia esta pensada para que varios compañeros puedan:

- levantar un escenario de red por zonas parecido al del diagrama
- exponer servicios vulnerables o de laboratorio en la DMZ
- centralizar logs en Grafana/Loki
- monitorizar la actividad en Wazuh
- generar trafico de prueba y ver eventos en el IPS y en el SIEM

## Material rapido para el equipo

- guia corta: `topology/CHEATSHEET.md`
- diagrama del compose: `topology/assets/topology-compose-diagram.svg`

## Zonas de red

- `edge`: representa la salida hacia NAT/Internet.
- `dmz`: zona expuesta con `web`, `ldap`, `honeypot`, `proxy`, `firewall` e `ips`.
- `backend`: zona interna con `logs`, `grafana`, `agenteia`, `database` y el stack SIEM de Wazuh.

## Componentes y rol de cada uno

- `nat1`: nodo simbolico que representa el exterior.
- `firewall`: salto entre `edge` y `dmz`, con `iptables` basico y politicas restrictivas.
- `ips`: sensor Suricata conectado entre `dmz` y `backend`.
- `web`: DVWA en la DMZ.
- `ldap`: OpenLDAP en la DMZ.
- `honeypot`: Cowrie para capturar sesiones SSH/Telnet.
- `proxy`: Nginx que publica `web`, `grafana`, `wazuh.dashboard` y `agenteia`.
- `logs`: Loki para centralizacion de eventos.
- `dmz.forwarder`: Fluent Bit que recoge logs de la DMZ y los envia a Loki.
- `grafana`: exploracion de logs centralizados.
- `agenteia`: microservicio HTTP de ejemplo para simular un backend de IA.
- `database`: PostgreSQL para la capa de datos.
- `wazuh.manager`, `wazuh.indexer`, `wazuh.dashboard`: SIEM principal.
- `*.agent`: agentes Wazuh sidecar para `web`, `honeypot`, `proxy`, `ips` y `agenteia`.

## Hardening aplicado

- `security_opt: no-new-privileges:true` en servicios del entorno nuevo.
- segmentacion en tres redes Docker separadas.
- `firewall` con politicas `DROP` por defecto y aperturas puntuales.
- `ips` con Suricata y reglas locales de laboratorio.
- forwarding de logs DMZ hacia Loki usando Fluent Bit.
- agentes Wazuh persistentes para no perder identidad al reiniciar.
- nombres de agente diferenciados respecto al stack original.

## Forwarding y telemetria

### Hacia Loki/Grafana

`dmz.forwarder` lee:

- `/var/log/apache2/*.log` del servicio `web`
- `/var/log/nginx/*.log` del `proxy`
- `/var/log/cowrie/cowrie.json` del `honeypot`
- `/var/log/suricata/eve.json` del `ips`

Todos esos logs se envian a Loki con etiqueta `job=dmz-forwarder`.

### Hacia Wazuh

Wazuh recibe eventos por agentes sidecar:

- `topology-web-agent`
- `topology-honeypot-agent`
- `topology-proxy-agent`
- `topology-ips-agent`
- `topology-agenteia-agent`

Ademas, el manager carga reglas locales en `topology/wazuh/local_rules.xml` para mejorar la lectura de alertas de Suricata y del servicio `agenteia`.

## Puertos publicados

- `8088`: acceso al servicio `web` a traves del `proxy`
- `5602`: acceso al dashboard de Wazuh a traves del `proxy`
- `3001`: acceso a Grafana a traves del `proxy`
- `8001`: acceso al servicio `agenteia` a traves del `proxy`
- `2225`: honeypot SSH
- `2226`: honeypot Telnet

## Requisitos

- Docker Desktop funcionando
- Docker Compose disponible
- certificados Wazuh generados
- al menos 4 GB de RAM disponibles para Docker; mejor 6 GB si se va a usar Wazuh + Grafana con comodidad

## Arranque paso a paso

1. Genera certificados Wazuh si aun no existen:

```powershell
docker compose -f generate-indexer-certs.yml run --rm generator
```

2. Levanta la topologia:

```powershell
docker compose -f docker-compose.topology.yml up -d
```

3. Comprueba que todo arranca:

```powershell
docker compose -f docker-compose.topology.yml ps
```

4. Si quieres revisar logs clave:

```powershell
docker logs elusive-topology-wazuh.manager-1
docker logs elusive-topology-ips-1
docker logs elusive-topology-dmz.forwarder-1
docker logs elusive-topology-proxy-1
```

## Parada y limpieza

Parar servicios:

```powershell
docker compose -f docker-compose.topology.yml down
```

Parar y borrar volumenes del stack alternativo:

```powershell
docker compose -f docker-compose.topology.yml down -v
```

## Validacion basica del entorno

### Proxy y servicios publicados

Prueba desde el host:

```powershell
curl http://localhost:8088/
curl http://localhost:8001/health
curl http://localhost:3001/login
curl http://localhost:5602/
```

### Honeypot

Prueba conexiones:

```powershell
ssh root@localhost -p 2225
telnet localhost 2226
```

### LDAP

Desde otro contenedor o desde el host si tienes cliente LDAP:

```powershell
docker exec -it elusive-topology-ldap-1 ldapsearch -x -H ldap://localhost -D "cn=admin,dc=elusive,dc=lab" -w admin123 -b "dc=elusive,dc=lab"
```

## Pruebas recomendadas para clase o laboratorio

### 1. Trafico web legitimo hacia DVWA

Abre:

- `http://localhost:8088`

Efecto esperado:

- logs en `web`
- logs en `proxy`
- eventos visibles en Grafana/Loki
- agente `topology-web-agent` activo en Wazuh

### 2. Intento de SQLi simple contra DVWA

Prueba por navegador o con curl:

```powershell
curl "http://localhost:8088/vulnerabilities/sqli/?id=1 union select 1,2&Submit=Submit"
```

Efecto esperado:

- Suricata genera alerta `ELUSIVE possible SQLi probe against DVWA`
- el evento entra en `eve.json`
- aparece en Loki
- Wazuh puede disparar la regla `100101`

### 3. Interaccion con el honeypot

```powershell
ssh admin@localhost -p 2225
```

Usa credenciales falsas. Efecto esperado:

- Cowrie registra la sesion
- Suricata detecta acceso al honeypot
- Wazuh ve actividad del agente `topology-honeypot-agent`

### 4. Peticion al servicio AgenteIA

```powershell
curl http://localhost:8001/
curl -X POST http://localhost:8001/ask -d "{\"prompt\":\"resume la DMZ\"}"
```

Efecto esperado:

- `agenteia` escribe logs JSON
- Wazuh recibe eventos del agente `topology-agenteia-agent`
- Loki muestra los accesos del servicio

### 5. Acceso LDAP

Genera una consulta LDAP o simplemente conecta al puerto 389. Efecto esperado:

- Suricata emite `ELUSIVE LDAP access in DMZ`

## Detecciones incluidas

Reglas locales de Suricata en `topology/ips/rules/local.rules`:

- acceso HTTP al servidor web DMZ
- intento simple de SQLi sobre DVWA
- intento simple de path traversal
- acceso LDAP
- interaccion SSH/Telnet con el honeypot
- trafico este-oeste DMZ hacia backend

Reglas locales de Wazuh en `topology/wazuh/local_rules.xml`:

- `100100`: alerta generica de Suricata
- `100101`: posible SQLi sobre DVWA
- `100102`: interaccion SSH con honeypot
- `100103`: acceso LDAP en DMZ
- `100110`: evento del servicio `agenteia`
- `100111`: peticion a `/ask` en `agenteia`

## Dónde mirar cada cosa

### Wazuh

- URL: `http://localhost:5602`
- usuario: `admin`
- password: `SecretPassword`

Revisa:

- **Agents** para confirmar que todos los `topology-*` estan activos
- **Security events** para buscar reglas `10010x`

### Grafana

- URL: `http://localhost:3001`
- usuario: `admin`
- password: `SecretPassword`

Explora Loki con consultas como:

- `{job="dmz-forwarder"}`
- `{job="dmz-forwarder", tag="dmz.ips"}`
- `{job="dmz-forwarder", tag="dmz.honeypot"}`

### Logs directos por contenedor

```powershell
docker exec -it elusive-topology-ips-1 sh -c "tail -n 20 /var/log/suricata/eve.json"
docker exec -it elusive-topology-proxy-1 sh -c "tail -n 20 /var/log/nginx/access.log"
docker exec -it elusive-topology-honeypot-1 sh -c "tail -n 20 /cowrie/cowrie-git/var/log/cowrie/cowrie.json"
```

## Problemas comunes

### Certificados Wazuh

Si faltan, el dashboard o el indexer no levantaran. Ejecuta:

```powershell
docker compose -f generate-indexer-certs.yml run --rm generator
```

### Agentes Wazuh en `disconnected`

Si reaparece el error de agentes duplicados:

1. borra los agentes antiguos desde el dashboard
2. recrea solo los agentes del stack alternativo

```powershell
docker compose -f docker-compose.topology.yml up -d --force-recreate web.agent honeypot.agent proxy.agent ips.agent agenteia.agent
```

### Puertos ocupados

Si `8088`, `5602`, `3001`, `8001`, `2225` o `2226` ya estan usados, cambia los puertos publicados en `docker-compose.topology.yml`.

### Docker Desktop con pocos recursos

Wazuh y OpenSearch consumen bastante memoria. Si algo reinicia en bucle, asigna mas RAM a Docker Desktop.

## Estructura de archivos relevante

- `docker-compose.topology.yml`: stack nuevo completo
- `topology/CHEATSHEET.md`: guia rapida de pruebas para compañeros
- `topology/assets/topology-compose-diagram.svg`: diagrama visual del compose real
- `topology/firewall/init.sh`: reglas iniciales del firewall
- `topology/ips/suricata.yaml`: configuracion de Suricata
- `topology/ips/rules/local.rules`: reglas IDS/IPS del laboratorio
- `topology/fluent-bit/fluent-bit.conf`: forwarding de logs DMZ
- `topology/grafana/provisioning/datasources/loki.yml`: datasource de Loki
- `topology/agents/*.conf`: agentes Wazuh de la topologia
- `topology/wazuh/local_rules.xml`: reglas Wazuh para este entorno

## Notas finales

- El `docker-compose.yml` original sigue intacto y se puede usar aparte.
- Este stack alternativo esta pensado como base de practicas, no como entorno de produccion.
- `firewall` e `ips` representan segmentacion y observacion de red dentro de las limitaciones normales de Docker bridge.
