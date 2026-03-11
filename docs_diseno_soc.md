# Justificación del diseño SOC en Docker

## Objetivo
El diseño busca emular una red corporativa realista segmentada en zonas (WAN, DMZ, corporativa y SOC), con telemetría de endpoints (XDR open source), detección perimetral, centralización de eventos y consumo analítico.

## Decisiones de arquitectura

1. **Segmentación por redes Docker (micro-segmentación lógica)**
   - `wan_net`: salida simulada a Internet/NAT.
   - `dmz_net`: servicios expuestos y señuelo.
   - `corp_net`: activos internos (endpoints y base de datos).
   - `soc_net`: componentes de monitorización y análisis.

2. **Router + firewall en dos planos**
   - `edge-firewall`: borde norte-sur (NAT y salto hacia DMZ).
   - `internal-router`: control este-oeste entre red corporativa y SOC con política por puertos.

3. **DMZ realista con servicios de exposición y engaño**
   - `idps` (Suricata): inspección de tráfico y generación de eventos de red.
   - `ldap` + `bastion`: simulación de acceso administrativo y directorio.
   - `web` (Nginx): servicio público en DMZ.
   - `honeypot` (Cowrie): superficie de detección temprana de atacantes.

4. **XDR en dispositivos finales (open source)**
   - `endpoint-01` y `endpoint-02` ejecutan **Wazuh Agent**.
   - Los agentes registran y envían eventos al `xdr-collector` (Wazuh Manager).

5. **Pipeline de eventos: Colector -> SIEM -> Visualización**
   - `xdr-collector` recibe telemetría y alertas de agentes.
   - `wazuh-forwarder` (Filebeat) recopila `alerts.json` y lo indexa en `siem` (OpenSearch).
   - `grafana` consume índices de OpenSearch para observabilidad ejecutiva/SOC.

6. **Analítica asistida por IA**
   - `ai-agent` (Ollama) queda en `soc_net` para casos de uso como triage asistido, resumen de incidentes o clasificación inicial de alertas.

## Flujo de logs esperado
1. Endpoints (`endpoint-*`) generan eventos de seguridad y sistema.
2. Wazuh Agent envía eventos al `xdr-collector`.
3. `wazuh-forwarder` lee alertas normalizadas del manager.
4. OpenSearch (`siem`) almacena y permite búsqueda/correlación.
5. Grafana consulta índices para paneles SOC.

## Mejoras recomendadas para producción
- Sustituir contraseñas embebidas por `.env` + Docker Secrets.
- Activar TLS/mTLS entre agentes, collector, SIEM y paneles.
- Añadir SOAR (por ejemplo Shuffle/TheHive+Cortex) para respuesta.
- Incluir escáner de vulnerabilidades (OpenVAS/Greenbone) en red interna.
- Integrar backup, retención por políticas y hardening de imágenes.
- Añadir un reverse proxy WAF (por ejemplo Nginx + ModSecurity) delante del web.

## Nota operativa
Este compose prioriza **fidelidad de arquitectura** y trazabilidad de flujo SOC sobre tuning de rendimiento. Para ejecutar en equipos modestos, puede arrancarse por perfiles o deshabilitar servicios pesados (OpenSearch/Ollama) temporalmente.
