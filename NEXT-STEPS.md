# Proximos pasos

Este documento recoge posibles siguientes iteraciones del laboratorio para hacerlo mas util, mas realista y mas presentable.

## 1. Reforzar el honeypot como sensor temprano

Idea principal:

- dar mas protagonismo al honeypot para detectar amenazas antes de que impacten en `web`, `ldap` o el resto de la red

Objetivos posibles:

- mover o duplicar el honeypot a una posicion mas expuesta en `edge` o en una subzona previa a la `dmz`
- capturar mas intentos SSH reales
- correlacionar los eventos del honeypot con reglas Wazuh para marcar IPs hostiles recurrentes
- usar esos eventos como disparador de bloqueo preventivo en el `firewall`

Mejoras concretas:

- crear reglas Wazuh para bloquear IPs tras varios `login.failed` en Cowrie
- etiquetar IPs que ataquen el honeypot como `hostile source`
- añadir paneles en Grafana solo para actividad del honeypot
- separar visualmente actividad legitima de actividad maliciosa

## 2. Bloqueo preventivo basado en honeypot

Estado actual:

- el bloqueo activo esta centrado en SQLi repetido contra DVWA

Siguiente evolucion:

- bloquear tambien IPs que interactuen repetidamente con el honeypot
- definir umbrales distintos para SSH y ataques web
- mantener listas temporales de IPs bloqueadas

Casos utiles:

- 3 o 5 intentos fallidos SSH en menos de 1 minuto
- multiples sesiones cortas desde la misma IP
- combinacion de actividad en honeypot + web en una misma ventana temporal

## 3. Mejorar la parte IDS/IPS

- hacer que Suricata genere mas `alert` reales y menos ruido estadistico
- ampliar reglas para path traversal, brute force, escaneo y LDAP sospechoso
- evaluar si conviene un modo mas cercano a IPS real para ciertos flujos de laboratorio

## 4. Correlacion en Wazuh

- crear reglas que unan eventos de Suricata, honeypot y Apache
- distinguir fases de ataque: reconocimiento, acceso inicial, explotacion, persistencia
- crear niveles de severidad mas claros para clase o demo

## 5. Presentacion y operativa

- añadir un dashboard de Grafana mas orientado a SOC
- crear un dashboard o mini panel para ver IPs bloqueadas y desbloquearlas
- generar una guia de practicas por escenarios
- preparar capturas esperadas para que cada companero pueda validar rapido

## 6. Persistencia y automatizacion

- automatizar el despliegue limpio del laboratorio
- documentar como regenerar agentes sin romper enrollment
- añadir scripts de ayuda para bloquear y desbloquear IPs manualmente
- versionar mejor dashboards y reglas

## 7. Orden recomendado

Si hubiera que priorizar, este seria un buen orden:

1. bloqueo preventivo usando eventos del honeypot
2. mas reglas de correlacion en Wazuh
3. paneles mejores en Grafana
4. automatizacion de tareas operativas
5. mejoras mas avanzadas en Suricata

## 8. Propuesta inmediata

La siguiente mejora mas natural seria:

- usar Cowrie como detector temprano
- crear reglas Wazuh para `login.failed` y `session.connect`
- disparar bloqueo temporal en el `firewall` cuando una IP muestre comportamiento claramente hostil

Eso encaja muy bien con la idea del laboratorio y le da al honeypot una funcion mas real dentro de la defensa.
