#!/bin/bash

CONFIG_DIR="/etc/front-manager"
SITE_DIR="/etc/nginx/sites-enabled"
BIN="/usr/local/bin/front"

mkdir -p $CONFIG_DIR

function banner(){
echo "=============================="
echo "   FRONT NGINX MANAGER V3"
echo "=============================="
}

function reload_nginx(){
nginx -t && systemctl reload nginx
}

function validate_ip(){
if [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
return 0
else
return 1
fi
}

function add_front(){

read -p "Username: " user
read -p "Backend IP: " ip
read -p "Backend Port: " port
read -p "Days until expiration: " days

validate_ip $ip
if [ $? -ne 0 ]; then
echo "Invalid IP"
exit
fi

exp=$(date -d "+$days days" +"%Y-%m-%d")

cat > $SITE_DIR/$user.conf <<EOF
location /$user {
 proxy_pass http://$ip:$port;
 proxy_http_version 1.1;
 proxy_set_header Upgrade \$http_upgrade;
 proxy_set_header Connection "upgrade";
 proxy_set_header Host \$host;
}
EOF

echo "$user $ip $port $exp" >> $CONFIG_DIR/users.db

reload_nginx

echo "User created"
}

function list_front(){

echo "Active Frontends"
cat $CONFIG_DIR/users.db

}

function delete_front(){

read -p "Username to delete: " user

sed -i "/^$user /d" $CONFIG_DIR/users.db

rm -f $SITE_DIR/$user.conf

reload_nginx

echo "User removed"

}

function expire_check(){

today=$(date +"%Y-%m-%d")

while read line
do

user=$(echo $line | awk '{print $1}')
exp=$(echo $line | awk '{print $4}')

if [[ "$today" > "$exp" ]]; then

rm -f $SITE_DIR/$user.conf
sed -i "/^$user /d" $CONFIG_DIR/users.db

echo "Expired user removed: $user"

fi

done < $CONFIG_DIR/users.db

reload_nginx

}

function install_ssl(){

read -p "Domain: " domain

certbot --nginx -d $domain

}

function install_cli(){

cp $0 $BIN
chmod +x $BIN

echo "Command installed: front"

}

function install_cron(){

cat > /etc/cron.hourly/front-expire-check <<EOF
#!/bin/bash
$BIN expire
EOF

chmod +x /etc/cron.hourly/front-expire-check

echo "Cron installed"

}

function menu(){

banner

echo "1 Add Frontend"
echo "2 Install SSL"
echo "3 List Frontends"
echo "4 Delete Frontend"
echo "5 Run Expire Check"
echo "6 Install CLI Command"
echo "7 Install Expiration Cron"
echo "0 Exit"

read -p "Option: " opt

case $opt in

1)add_front;;
2)install_ssl;;
3)list_front;;
4)delete_front;;
5)expire_check;;
6)install_cli;;
7)install_cron;;
0)exit;;

esac

}

if [[ "$1" == "expire" ]]; then
expire_check
exit
fi

while true
do
menu
done