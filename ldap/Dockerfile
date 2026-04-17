FROM osixia/openldap:1.5.0

COPY bootstrap/10-tokens.ldif /container/service/slapd/assets/config/bootstrap/ldif/custom/10-tokens.ldif
COPY bootstrap/11-acl.ldif /container/service/slapd/assets/config/bootstrap/ldif/custom/11-acl.ldif
COPY start.sh /opt/lab/ldap/start.sh
