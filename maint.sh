#!/bin/bash
# Using thttpd as temporary maintenance page server
# RPM based systems; CentOS/Fedora/Red Hat

prog=maint
RETVAL=0

start() {
# Stop and disable httpd, varnish, munin, and mysql start on reboot
if [ -e "/etc/init.d/httpd" ]; then
    /etc/init.d/httpd stop;
    chkconfig httpd off;
fi

if [ -e "/etc/init.d/varnish" ]; then
    /etc/init.d/varnish stop;
    chkconfig varnish off;
fi

if [ -e "/etc/init.d/mysqld" ]; then
    /etc/init.d/mysqld stop;
    chkconfig mysqld off;
fi

if [ -e "/etc/init.d/munin" ]; then
    /etc/init.d/munin stop;
    chkconfig munin off;
fi

# Install thttpd and perl
yum install -y thttpd perl

# Check for thttpd directory
if [ ! -d "/var/www/thttpd" ]; then
    mkdir /var/www/thttpd;
fi

# Check for thttpd/cgi-bin directory
if [ ! -d "/var/www/thttpd/cgi-bin" ]; then
    mkdir /var/www/thttpd/cgi-bin;
fi

# Configure thttpd
echo "Configuring thttpd"
sed -i.bak 's/^chroot/nochroot/' /etc/thttpd.conf
echo "cgipat=**.cgi" >> /etc/thttpd.conf

# Create maintenance CGI script
echo "Creating maintenance CGI script"
cat << EOF > /var/www/thttpd/cgi-bin/maintenance.cgi
#!/usr/bin/perl

print "Content-type: text/html\nStatus: 503 Service Unavailable\n";
print "
<!DOCTYPE html>
<html>
<head>
<title>Maintenance</title>
</head>
<body>
<h3>We are currently undergoing maintenance; will be back shortly.</h3>
<hr />
<h5>Thank you for your patience.</h5>
</body>
</html>\n\n";
EOF

sleep 3

# Check if index.html exists
if [ -e /var/www/thttpd/index.html ]; then
    mv -f /var/www/thttpd/index.html{,.original};
fi

# Symlink index.html to maintenance.cgi
echo "Generating symlinks and updating permissions"
ln -s /var/www/thttpd/cgi-bin/maintenance.cgi /var/www/thttpd/index.html
chmod 755 /var/www/thttpd/cgi-bin/maintenance.cgi
sleep 3

# Start thttpd; set to start in case of reboot
if [ -e "/etc/init.d/thttpd" ]; then
    /etc/init.d/thttpd start;
    chkconfig thttpd on;
fi

RETVAL=$?
}

stop() {

# Stop thttpd and disable start on reboot
if [ -e "/etc/init.d/thttpd" ]; then
    /etc/init.d/thttpd stop;
    chkconfig thttpd off;
fi

# Remove thttpd
echo "Removing thttpd from system"
rpm -e --nodeps thttpd
rm -rf /var/www/thttpd
rm -f /etc/thttpd*

# Delete thttpd user
userdel -rf thttpd 2> /dev/null
sleep 5

# Start and enable httpd, varnish, munin, and mysql start on reboot
if [ -e "/etc/init.d/httpd" ]; then
    /etc/init.d/httpd start;
    chkconfig httpd on;
fi

if [ -e "/etc/init.d/varnish" ]; then
    /etc/init.d/varnish start;
    chkconfig varnish on;
fi

if [ -e "/etc/init.d/mysqld" ]; then
    /etc/init.d/mysqld start;
    chkconfig mysqld on;
fi

if [ -e "/etc/init.d/munin" ]; then
    /etc/init.d/munin start;
    chkconfig munin on;
fi

RETVAL=$?
}

# Parse command-line argument
case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	*)
		echo $"Usage: $prog {start|stop}"
		RETVAL=2
esac

exit $RETVAL
