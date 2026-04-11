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

## Credenciales

- Wazuh: `admin / SecretPassword`
- Grafana: `admin / SecretPassword`
- LDAP: `cn=admin,dc=elusive,dc=lab / admin123`

## Regla importante

- Desde Windows usa `localhost`.
- Desde `attacker` usa las IP internas `172.31.x.x`.
- Para validar bloqueo por IP, el ataque debe salir desde `attacker`.

Entrar al atacante:

```powershell
docker exec -it elusive-lab-attacker-1 sh
```

## Agentes esperados

- `lab-web-agent`
- `lab-honeypot-agent`
- `lab-proxy-agent`
- `lab-ips-agent`
- `lab-agenteia-agent`
- un agente del firewall

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

### Honeypot Telnet

```sh
nc -vz 172.31.0.40 2223
```

### LDAP

```sh
nc -vz 172.31.0.30 389
```

## Ver bloqueo

```powershell
docker exec elusive-lab-firewall.agent-1 sh -c "tail -n 50 /var/ossec/logs/active-responses.log"
docker exec elusive-lab-firewall-1 sh -c "iptables -S"
```

## Quitar bloqueo

```powershell
docker exec elusive-lab-firewall-1 sh -c "iptables -D INPUT -s 172.30.0.20 -j DROP; iptables -D FORWARD -s 172.30.0.20 -j DROP"
docker exec elusive-lab-firewall-1 sh -c "iptables -S"
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
