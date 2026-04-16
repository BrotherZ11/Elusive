# Chuleta rapida

## Arranque

```powershell
docker compose -f generate-indexer-certs.yml run --rm generator
docker compose -f docker-compose.lab.yml up -d
docker compose -f docker-compose.lab.yml ps
```

## URLs

- DVWA: `http://localhost:8088`
- Wazuh: `http://localhost:5602`
- Grafana: `http://localhost:3001`
- AgenteIA: `http://localhost:8001`
- Kali web grupo 1: `https://localhost:6901`
- Kali web grupo 2: `https://localhost:6902`
- Kali web grupo 3: `https://localhost:6903`

## Credenciales

- Wazuh: `admin / SecretPassword`
- Grafana: `admin / SecretPassword`
- LDAP: `cn=admin,dc=elusive,dc=lab / admin123`
- Honeypot SSH: `root` con password vacia

## Regla importante

- Desde Windows usa `localhost`.
- Desde `attacker01`, `attacker02` o `attacker03` usa las IP internas `172.31.x.x`.
- Para validar bloqueo por IP, el ataque debe salir desde `attacker01`, `attacker02` o `attacker03`.

Entrar a un atacante:

```powershell
docker exec -it elusive-lab-attacker01-1 sh
```

## Agentes esperados

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

## Endpoints internos (simulados)

- `endpoint.workstation` (`172.33.0.10`)
- `endpoint.mobile01` (`172.33.0.20`)
- `endpoint.mobile02` (`172.33.0.21`)
- todos usan XDR basado en Wazuh y envian telemetria desde `/var/log/endpoint/activity.log`

## Pruebas rapidas

### Web normal

```powershell
curl http://localhost:8088/
```

### SQLi

```sh
curl "http://172.31.0.20/vulnerabilities/sqli/?id=1%20union%20select%201,2&Submit=Submit"
```

### Activar bloqueo

```sh
for i in 1 2 3 4 5; do
  curl -s "http://172.31.0.20/vulnerabilities/sqli/?id=1%20union%20select%201,2&Submit=Submit" >/dev/null
  sleep 1
done
```

### Honeypot SSH

```sh
ssh admin@172.31.0.40 -p 2222
```

### Fuerza bruta SSH en honeypot

Instala `sshpass` en un atacante si hace falta:

```sh
apk add --no-cache sshpass
```

Genera intentos fallidos repetidos:

```sh
for i in 1 2 3 4; do
  sshpass -p wrongpass ssh -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -p 2222 admin@172.31.0.40 exit >/dev/null 2>&1 || true
  sleep 1
done
```

### Rafaga de conexiones SSH al honeypot

Genera conexiones repetidas sin autenticar:

```sh
for i in 1 2 3 4 5 6; do
  nc -vz 172.31.0.40 2222 >/dev/null 2>&1
  sleep 1
done
```

### Login exitoso en SSH honeypot

Un acceso exitoso al honeypot tambien provoca bloqueo:

Usuario conocido:

- `root`
- password vacia, pulsa `Enter`

```sh
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 root@172.31.0.40
```

### LDAP

```sh
nc -vz 172.31.0.30 389
```

### Ver tokens LDAP

```powershell
docker exec elusive-lab-ldap-1 ldapsearch -x -H ldap://localhost:389 -D "cn=admin,dc=elusive,dc=lab" -w admin123 -b "ou=tokens,dc=elusive,dc=lab" "(objectClass=inetOrgPerson)" cn description
```

### Ataque LDAP honeytoken

Instala el cliente LDAP en un atacante si hace falta:

```sh
apk add --no-cache openldap-clients
```

Lanza una consulta al honeytoken:

```sh
ldapsearch -x -H ldap://172.31.0.30:389 -D "cn=admin,dc=elusive,dc=lab" -w admin123 -b "ou=tokens,dc=elusive,dc=lab" "(cn=SOC-admin)" cn
```

### Activar bloqueo por LDAP

```sh
for i in 1 2; do
  ldapsearch -x -H ldap://172.31.0.30:389 -D "cn=admin,dc=elusive,dc=lab" -w admin123 -b "ou=tokens,dc=elusive,dc=lab" "(cn=SOC-admin)" cn >/dev/null
  sleep 1
done
```

## Ver bloqueo

```powershell
docker exec elusive-lab-wazuh.manager-1 sh -c "grep '100121\|100131\|100132\|100133\|100134\|100135\|firewall-drop' /var/ossec/logs/alerts/alerts.json | tail -n 40"
docker exec elusive-lab-wazuh.manager-1 sh -c "tail -n 20 /opt/lab/firewall-state/commands.log"
docker exec elusive-lab-firewall-1 sh -c "iptables -S LAB_BLOCK; echo '---'; iptables -t nat -S LAB_BLOCK_WEB"
```

### Ver si una IP concreta sigue bloqueada

Sustituye `172.30.0.20` por la IP del atacante que quieras comprobar:

```powershell
docker exec elusive-lab-firewall-1 sh -c "iptables -S LAB_BLOCK | grep 172.30.0.20; echo '---'; iptables -S INPUT | grep 172.30.0.20; echo '---'; iptables -t nat -S LAB_BLOCK_WEB | grep 172.30.0.20"
```

### Comprobar desde el atacante que la web muestra la pagina de bloqueo

```sh
curl -sv --max-time 5 http://172.31.0.20/ >/tmp/block.out 2>/tmp/block.err
head -n 6 /tmp/block.out
cat /tmp/block.err | sed -n '1,18p'
```

### Comprobar que LDAP y honeypot siguen bloqueados

```sh
nc -zvw3 172.31.0.30 389
nc -zvw3 172.31.0.40 2222
```

## Quitar bloqueo

### Deshacer bloqueo manualmente para una IP

Sustituye `172.30.0.20` por la IP que quieras liberar:

```powershell
docker exec elusive-lab-wazuh.manager-1 sh -c "printf 'delete 172.30.0.20\n' >> /opt/lab/firewall-state/commands.log"
docker exec elusive-lab-firewall-1 sh -c "iptables -S LAB_BLOCK; echo '---'; iptables -t nat -S LAB_BLOCK_WEB"
```

### Limpiar una IP manualmente si quieres saltarte la cola

```powershell
docker exec elusive-lab-firewall-1 sh -c "iptables -D LAB_BLOCK -s 172.30.0.20 -j DROP 2>/dev/null || true; iptables -D INPUT -s 172.30.0.20 -p tcp --dport 8089 -j ACCEPT 2>/dev/null || true; iptables -t nat -D LAB_BLOCK_WEB -s 172.30.0.20 -d 172.31.0.20 -p tcp --dport 80 -j DNAT --to-destination 172.31.0.2:8089 2>/dev/null || true"
docker exec elusive-lab-firewall-1 sh -c "iptables -S LAB_BLOCK; echo '---'; iptables -t nat -S LAB_BLOCK_WEB"
```

### Ver el historico de altas y bajas de bloqueo

```powershell
docker exec elusive-lab-wazuh.manager-1 sh -c "tail -n 30 /opt/lab/firewall-state/commands.log"
```

## Grafana

Consultas utiles:

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

## Guia completa

- `LAB-README.md`
