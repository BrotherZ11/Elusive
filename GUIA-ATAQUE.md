## Objetivo

Identificar servicios expuestos en la zona de laboratorio y probar tecnicas realistas de enumeracion, acceso y abuso.

Servicios que merece la pena revisar:

- aplicacion web HTTP
- servicio SSH
- servicio LDAP

## Herramientas recomendadas

- `nmap`: descubrimiento de puertos y fingerprinting basico
- `curl`: pruebas rapidas HTTP y repeticion de peticiones
- `nc` o `netcat`: comprobar puertos TCP y banners simples
- `gobuster` o `ffuf`: enumeracion de rutas web
- `sqlmap`: automatizar pruebas SQLi si detectais parametros interesantes
- `ssh` y `sshpass`: acceso SSH y repeticion de intentos de login
- `hydra`: fuerza bruta contra SSH o formularios si procede
- `ldapsearch`: enumeracion LDAP
- navegador web con proxy si quereis revisar la aplicacion manualmente

## Fase 1. Reconocimiento

1. Haced un barrido inicial de puertos TCP.
2. Identificad versiones, banners y servicios accesibles.
3. Priorizad HTTP, SSH y LDAP.

Ejemplos utiles:

```sh
nmap -sV -sC <objetivo>
```

```sh
nmap -p 22,23,80,389 <objetivo>
```

```sh
nc -vz <objetivo> 22
nc -vz <objetivo> 23
nc -vz <objetivo> 389
```

## Fase 2. Aplicacion web

Cosas a probar:

- rutas comunes y paneles de login
- parametros GET y POST manipulables
- formularios vulnerables a SQLi
- directorios o endpoints ocultos
- comportamiento del proxy o frontal web

Herramientas:

- `curl`
- `gobuster`
- `ffuf`
- `sqlmap`

Ejemplos:

```sh
curl -i http://<web>/
```

```sh
gobuster dir -u http://<web>/ -w /usr/share/wordlists/dirb/common.txt
```

```sh
sqlmap -u "http://<web>/ruta?param=1" --batch
```

Pistas utiles:

- mirad si hay aplicaciones deliberadamente vulnerables
- revisad parametros como `id`, `user`, `page`, `search`
- si una peticion responde distinto ante comillas, `union select` o cambios de tipo, profundizad

## Fase 3. SSH

El servicio SSH es una superficie clara para:

- enumeracion de banner
- prueba manual de credenciales
- fuerza bruta controlada
- comprobacion de usuarios comunes

Herramientas:

- `ssh`
- `sshpass`
- `hydra`

Ejemplos:

```sh
ssh usuario@<ssh-host> -p <puerto>
```

```sh
sshpass -p 'clave' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null usuario@<ssh-host> -p <puerto>
```

```sh
hydra -l admin -P /usr/share/wordlists/rockyou.txt ssh://<ssh-host> -s <puerto>
```

Recomendacion:

- combinad intentos manuales y automatizados
- probad usuarios tipicos como `admin`, `root`, `test`, `dev`, `soc`, `monitor`

## Fase 5. LDAP

LDAP suele dar mucho juego en laboratorio:

- enumeracion anonima si está permitida
- bind con credenciales por defecto o filtradas
- busquedas de usuarios, cuentas de servicio y OU interesantes
- deteccion de entradas llamativas

Herramienta principal:

- `ldapsearch`

Ejemplos:

```sh
ldapsearch -x -H ldap://<ldap-host>:<puerto> -b "dc=example,dc=lab"
```

```sh
ldapsearch -x -H ldap://<ldap-host>:<puerto> -D "cn=admin,dc=example,dc=lab" -w <password> -b "dc=example,dc=lab"
```

Buscad especialmente:

- usuarios administrativos
- cuentas de servicio
- OU de tokens o credenciales
- descripciones demasiado informativas

## Ataques recomendados en clase

- enumeracion de puertos y servicios con `nmap`
- descubrimiento de contenido web con `gobuster` o `ffuf`
- pruebas de SQLi manuales y con `sqlmap`
- fuerza bruta SSH con `sshpass` o `hydra`
- rafagas de conexiones SSH con `nc`
- consultas LDAP con `ldapsearch`
- busqueda de credenciales reutilizadas o cuentas atractivas

## Enfoque sugerido

1. Empezad por reconocimiento general.
2. Elegid dos vectores principales.
3. Profundizad en web y en servicios de acceso remoto.
4. Si encontrais credenciales, reutilizadlas en otros servicios.
5. Si detectais una cuenta especialmente interesante en LDAP, comprobad si aparece en SSH, web o proxy.

## Higiene minima

- guardad comandos y resultados
- anotad banners, usuarios y rutas interesantes
- repetid ataques con pausas cortas para ver diferencias de comportamiento
- si un servicio responde “demasiado fácil”, no asumáis que es casual

## Idea importante

No deis por hecho que un servicio expuesto existe solo para ser explotado de forma directa. En este tipo de laboratorio, reconocimiento, fuerza bruta, reutilizacion de credenciales y consultas “curiosas” pueden ser tan relevantes como una explotación clásica.
