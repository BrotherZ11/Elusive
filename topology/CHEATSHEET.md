# Chuleta practica

Guia rapida para que cada compañero pueda levantar el entorno, generar trafico y validar que todo esta funcionando.

## 1. Arranque minimo

Generar certificados si faltan:

```powershell
docker compose -f generate-indexer-certs.yml run --rm generator
```

Levantar el stack:

```powershell
docker compose -f docker-compose.topology.yml up -d
```

Comprobar contenedores:

```powershell
docker compose -f docker-compose.topology.yml ps
```

## 2. URLs y credenciales

- DVWA por proxy: `http://localhost:8088`
- Wazuh Dashboard por proxy: `http://localhost:5602`
- Grafana por proxy: `http://localhost:3001`
- AgenteIA por proxy: `http://localhost:8001`
- Honeypot SSH: `localhost:2225`
- Honeypot Telnet: `localhost:2226`

Credenciales:

- Wazuh: `admin` / `SecretPassword`
- Grafana: `admin` / `SecretPassword`
- LDAP admin DN: `cn=admin,dc=elusive,dc=lab`
- LDAP password: `admin123`

## 3. Qué revisar nada mas arrancar

### Wazuh

Entra en `http://localhost:5602` y comprueba que aparecen estos agentes:

- `topology-web-agent`
- `topology-honeypot-agent`
- `topology-proxy-agent`
- `topology-ips-agent`
- `topology-agenteia-agent`

### Grafana

Entra en `http://localhost:3001` y prueba estas consultas en Explore:

- `{job="dmz-forwarder"}`
- `{job="dmz-forwarder", tag="dmz.ips"}`
- `{job="dmz-forwarder", tag="dmz.honeypot"}`
- `{job="dmz-forwarder", tag="dmz.web"}`

## 4. Pruebas rapidas

### Prueba A. Trafico web normal

```powershell
curl http://localhost:8088/
```

Debes ver:

- acceso en el proxy
- acceso en DVWA
- logs en Grafana/Loki

### Prueba B. SQLi simple contra DVWA

```powershell
curl "http://localhost:8088/vulnerabilities/sqli/?id=1 union select 1,2&Submit=Submit"
```

Debes ver:

- alerta Suricata en `eve.json`
- entrada en Loki con tag `dmz.ips`
- evento en Wazuh asociado a la regla `100101`

### Prueba C. Path traversal simple

```powershell
curl "http://localhost:8088/../../../../etc/passwd"
```

Debes ver:

- alerta Suricata por intento de traversal
- trazas del proxy y del web

### Prueba D. Honeypot SSH

```powershell
ssh admin@localhost -p 2225
```

Usa una contraseña falsa. Debes ver:

- evento en Cowrie
- alerta Suricata de interaccion con honeypot
- eventos en Loki y Wazuh

### Prueba E. Honeypot Telnet

```powershell
telnet localhost 2226
```

Debes ver:

- registros del honeypot
- evento en Suricata

### Prueba F. Servicio AgenteIA

```powershell
curl http://localhost:8001/
curl -X POST http://localhost:8001/ask -d "{\"prompt\":\"resume la DMZ\"}"
```

Debes ver:

- logs JSON del servicio
- eventos en Wazuh del agente `topology-agenteia-agent`
- eventos en Loki

### Prueba G. LDAP

```powershell
docker exec -it elusive-topology-ldap-1 ldapsearch -x -H ldap://localhost -D "cn=admin,dc=elusive,dc=lab" -w admin123 -b "dc=elusive,dc=lab"
```

Debes ver:

- acceso al puerto LDAP
- alerta Suricata `ELUSIVE LDAP access in DMZ`

## 5. Comandos utiles

Logs del stack:

```powershell
docker logs elusive-topology-ips-1
docker logs elusive-topology-dmz.forwarder-1
docker logs elusive-topology-wazuh.manager-1
docker logs elusive-topology-proxy-1
```

Ver Suricata:

```powershell
docker exec -it elusive-topology-ips-1 sh -c "tail -n 50 /var/log/suricata/eve.json"
docker exec -it elusive-topology-ips-1 sh -c "tail -n 50 /var/log/suricata/fast.log"
```

Ver logs de DMZ:

```powershell
docker exec -it elusive-topology-proxy-1 sh -c "tail -n 30 /var/log/nginx/access.log"
docker exec -it elusive-topology-honeypot-1 sh -c "tail -n 30 /cowrie/cowrie-git/var/log/cowrie/cowrie.json"
```

## 6. Qué evidencia capturar

Cada compañero puede entregar:

- captura de `docker compose ps`
- captura de agentes activos en Wazuh
- captura de una consulta en Grafana/Loki
- captura de una alerta de Wazuh o Suricata
- comando usado para generar la prueba

## 7. Si algo falla

- si Wazuh no arranca, revisa certificados
- si los agentes salen `disconnected`, recrea los agentes del stack alternativo
- si Grafana no muestra datos, revisa `dmz.forwarder`
- si Suricata no genera alertas, revisa `topology/ips/rules/local.rules`

Guia larga:

- `topology/README.md`
