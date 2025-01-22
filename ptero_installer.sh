#!/bin/bash

sudo apt update && sudo apt upgrade -y

sudo apt install -y curl wget sudo gnupg2 ca-certificates lsb-release apt-transport-https software-properties-common

sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

docker --version

sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

docker-compose --version

sudo add-apt-repository ppa:ondrej/php
sudo apt update
sudo apt install -y php8.1 php8.1-cli php8.1-fpm php8.1-mysql php8.1-gd php8.1-mbstring php8.1-xml php8.1-curl php8.1-bcmath php8.1-zip

sudo apt install -y nginx

sudo apt install -y mariadb-server
sudo systemctl start mariadb
sudo systemctl enable mariadb

sudo mysql_secure_installation

sudo mysql -u root -p <<EOF
CREATE DATABASE pterodactyl;
CREATE USER 'pterodactyl'@'localhost' IDENTIFIED BY 'strongpassword';
GRANT ALL PRIVILEGES ON pterodactyl.* TO 'pterodactyl'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

cd /var/www
sudo wget https://github.com/pterodactyl/panel/releases/download/v1.0.0/panel.tar.gz
sudo tar -xzvf panel.tar.gz
cd pterodactyl

sudo apt install -y composer

sudo composer install --no-dev --optimize-autoloader

cp .env.example .env
sudo sed -i 's/DB_HOST=127.0.0.1/DB_HOST=127.0.0.1/' .env
sudo sed -i 's/DB_PORT=3306/DB_PORT=3306/' .env
sudo sed -i 's/DB_DATABASE=pterodactyl/DB_DATABASE=pterodactyl/' .env
sudo sed -i 's/DB_USERNAME=root/DB_USERNAME=pterodactyl/' .env
sudo sed -i 's/DB_PASSWORD=secret/DB_PASSWORD=strongpassword/' .env

php artisan key:generate --force

php artisan migrate --seed

sudo chown -R www-data:www-data /var/www/pterodactyl/*

echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" | sudo tee -a /etc/crontab > /dev/null

sudo tee /etc/nginx/sites-available/pterodactyl > /dev/null <<EOF
server {
    listen 80;
    server_name your-domain.com;

    root /var/www/pterodactyl/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        try_files \$uri =404;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
sudo systemctl reload nginx

echo "¡La instalación de Pterodactyl ha finalizado con éxito!"
