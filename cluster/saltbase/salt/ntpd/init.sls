ntpd:
  pkg:
    - installed

ntp-service:
  service:
    - running
    - name: ntpd
    - watch:
      - pkg: ntpd

