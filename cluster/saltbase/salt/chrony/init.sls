chrony:
  pkg:
    - installed

chrony-service:
  service:
    - running
    - name: chronyd
    - watch:
      - pkg: chrony

