#!/usr/bin/env bash
# Created by itffind@gmail.com at 2021/11/4
set -u
echo "Check system information!"
if [ -z "${BASH_VERSION:-}" ]
then
  abort "Bash is required to interpret this script."
fi

if grep -i -q 'CentOS' /etc/redhat-release; then
  echo "is CentOS"
else
  echo "CentOS !ok"
  exit 0
fi

if systemctl --version | grep -q 'systemd'; then
  echo "systemctl Installed"
else
  echo "systemctl not Installed"
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
watch_dir=/etc/watch
watch_file=/etc/watch/watch.ini
command=systemctl restart watch.service
EOF

touch /tmp/_app

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
StandardOutput=syslog
StandardError=syslog
;StandardError=inherit

[Install]
WantedBy=multi-user.target

EOF

# Create the main program file
cat >/usr/sbin/watch.sh<<EOF
#!/usr/bin/env bash
# Created by lilei at 2020/11/1
config_file=/etc/watch/watch.ini
watch_dirs=\$(grep watch_dir \$config_file | grep -v ';' | sed 's/ //g' | sed 's/watch_dir=//g' | sort -u |tr "\n" " ")
/usr/bin/inotifywait -mrq --timefmt '%Y-%m-%d %H:%M' --format '%T %w %f %e' -e create,delete,close_write,attrib,moved_to \$watch_dirs | while read watch_line; do
  result=\$(echo \$watch_line | grep -E "CLOSE_WRITE|MOVED_TO")
  echo \$result
  if [[ "\$result" != "" ]]; then
      watch_file=\$(echo \$watch_line | awk '{print \$3\$4}')
      watch_command=\$(cat \$config_file | grep -v '^\$' | grep -v ';' | grep -C 2 \$watch_file | head -n 5 | grep "command" | head -n 1 | sed 's/ = /=/g' | sed 's/command=//g')
      echo "\$watch_command"
      \$watch_command
  fi
done
EOF

chmod +x /usr/sbin/watch.sh

echo "
cat /usr/lib/systemd/system/watch.service
cat /etc/watch/watch.ini
cat /usr/sbin/watch.sh
systemctl enable watch.service
systemctl daemon-reload
systemctl restart watch.service
systemctl start watch.service
systemctl status watch.service
systemctl stop watch.service";

sleep 2

echo "Start service"
systemctl daemon-reload
systemctl enable watch.service
systemctl start watch.service
systemctl status watch.service
systemctl restart watch.service
systemctl status watch.service