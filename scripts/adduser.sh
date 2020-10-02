#!/bin/ash
# Add users

# Root
cat > /root/.cshrc << EOF
unsetenv DISPLAY || true
HISTCONTROL=ignoreboth
EOF

cp /root/.cshrc /root/.profile
echo "alpine" | chpasswd

# Remote
mkdir -p /etc/skel/
cat > /etc/skel/.logout << EOF
history -c
/bin/rm -f /opt/remote/.mysql_history
/bin/rm -f /opt/remote/.history
/bin/rm -f /opt/remote/.bash_history
EOF

cat > /etc/skel/.cshrc << EOF
set autologout = 30
set prompt = "\$ "
set history = 0
set ignoreeof
EOF

cp /etc/skel/.cshrc /etc/skel/.profile
adduser -D --home /opt/remote --shell /bin/ash remote
echo "alpine" | chpasswd
