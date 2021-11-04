#!/usr/bin/env bash
# Created by itffind@gmail.com at 2021/11/4
set -u
if [ -z "${BASH_VERSION:-}" ]
then
  abort "Bash is required to interpret this script."
fi

if grep -i -q 'CentOS' /etc/redhat-release; then
  echo "ok"
else
  echo "Centos !ok"
  exit 0
fi

if systemctl --version | grep -q 'systemd'; then
  echo "ok"
else
  echo "systemd !ok"
  exit 0
fi

if ! type inotifywait >/dev/null 2>&1; then
    echo 'inotifywait not Installed';
    yum install inotify-tools -y
else
    echo 'inotifywait Installed';
fi

# Write configuration file
mkdir -p /etc/watch

cat >/etc/watch/watch.ini<<EOF
; inotifywait service config

[app]
watch_file=/data/app/demo
command=du -sh
EOF

mkdir -p /data/app
touch /data/app/demo

# Create systemd file
cat >/usr/lib/systemd/system/watch.service<<EOF
[Unit]
Description=WatchService
Documentation=https://github.com/lonisy/WatchService

[Service]
Type=simple
Restart=always
RestartSec=3s
Environment=APP_ENV=release
ExecStart=/usr/sbin/watch.sh &
ExecReload=/usr/sbin/watch.sh &
ExecStop=/bin/kill -s TERM \$MAINPID
WorkingDirectory=/tmp

[Install]
WantedBy=multi-user.target

EOF

# Create the main program file
cat >/usr/sbin/watch.sh<<EOF
#!/usr/bin/env bash
# Created by lilei at 2020/11/1
config_file=/etc/watch/watch.ini
watch_files=\$(grep watch_file \$config_file | grep -v ';' | sed 's/ //g' | sed 's/watch_file=//g' | sort -u |tr "\n" " ")
/usr/bin/inotifywait -mq --timefmt '%Y-%m-%d %H:%M' --format '%T %w %f %e' -e open,close_write \$watch_files | while read watch_line; do
  result=\$(echo \$watch_line | grep "CLOSE_WRITE")
  if [[ "\$result" != "" ]]; then
      echo "\$result"
      watch_file=\$(echo \$watch_line | awk '{print \$3}')
      watch_command=\$(cat \$file | grep -v '^\$' | grep -v ';' | grep -C 1 \$watch_file | head -n 3 | grep "command" | sed 's/ = /=/g' | sed 's/command=//g')
      echo "\$watch_command"
      \$watch_command
  fi
done
EOF

chmod +x /usr/sbin/watch.sh

echo "systemctl enable watch.service
systemctl daemon-reload
systemctl restart watch.service
systemctl start watch.service
systemctl status watch.service
systemctl stop watch.service"

# Start service
systemctl daemon-reload
systemctl enable watch.service
systemctl start watch.service
systemctl status watch.service