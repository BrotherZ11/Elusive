# Elusive

SOC basico y funcional con Docker Compose para laboratorio ofensivo/defensivo:

- Wazuh SIEM completo: manager + indexer + dashboard.
- Endpoint expuesto por SSH.
- Servidor web vulnerable DVWA.
- Honeypot Cowrie (SSH/Telnet).
- Conectores de logs hacia Wazuh mediante agentes dedicados.

## Arquitectura

- `wazuh.manager`: correlacion SIEM, API y recepcion de eventos.
- `wazuh.indexer`: almacenamiento e indexacion.
- `wazuh.dashboard`: interfaz web de Wazuh.
- `endpoint`: objetivo SSH para pruebas de fuerza bruta y acceso remoto.
- `dvwa`: aplicacion web vulnerable.
- `honeypot`: Cowrie para capturar actividad maliciosa.
- `*.agent`: agentes Wazuh sidecar que leen logs de cada objetivo y los envian al manager.

## Requisitos

- Docker + Docker Compose.
- En Linux/WSL2, ajustar:

```bash
sudo sysctl -w vm.max_map_count=262144
```

## Despliegue

1. Genera certificados para el stack Wazuh:

```bash
docker compose -f generate-indexer-certs.yml run --rm generator
```

2. Levanta todo el laboratorio:

```bash
docker compose up -d
```

3. Comprueba estado:

```bash
docker compose ps
```

## Acceso a servicios

- Wazuh Dashboard: `http://IP_DEL_HOST:5601`
- Wazuh API: `https://IP_DEL_HOST:55000`
- DVWA: `http://IP_DEL_HOST:8080`
- Endpoint SSH: `IP_DEL_HOST:2223`
- Honeypot SSH: `IP_DEL_HOST:2222`
- Honeypot Telnet: `IP_DEL_HOST:2224`

Credenciales por defecto Wazuh Dashboard:

- Usuario: `admin`
- Password: `SecretPassword`

Credenciales endpoint SSH de laboratorio:

- Usuario: `student`
- Password: `student123`

## Validar que Wazuh recibe logs

1. Entra al dashboard y revisa **Agent management**: deben aparecer `dvwa-agent`, `endpoint-agent` y `honeypot-agent`.
2. Genera eventos:
   - Navega por DVWA e intenta login invalido.
   - Prueba SSH incorrecto contra el endpoint y contra el honeypot.
3. En **Security events**, filtra por nombre de agente para verificar ingestión.

## Exponer para ataques de otros grupos

Para pruebas desde fuera de tu red local:

1. Publica estos puertos en el router/firewall hacia la maquina Docker:
   - `5601`, `55000`, `8080`, `2222`, `2223`, `2224`
2. Comparte IP publica o DNS con el resto de grupos.
3. Si usas cloud, abre los mismos puertos en el security group.

## Archivos clave

- `docker-compose.yml`: stack completo SOC + objetivos.
- `generate-indexer-certs.yml`: generacion de certificados TLS.
- `config/wazuh_cluster/wazuh_manager.conf`: manager Wazuh (incluye recepcion syslog UDP/514).
- `config/agents/*.conf`: conectores de logs por agente sidecar.

## Nota de seguridad

Este entorno es deliberadamente vulnerable. Ejecutalo solo en red aislada de laboratorio y nunca en infraestructura productiva.
