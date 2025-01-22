#!/bin/bash

# Actualiza el sistema
echo "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar dependencias básicas
echo "Instalando dependencias..."
sudo apt install -y curl wget sudo gnupg2 ca-certificates lsb-release apt-transport-https software-properties-common

# Instalar Docker
echo "Instalando Docker..."
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Verificar Docker
echo "Verificando instalación de Docker..."
docker --version

# Instalar Docker Compose
echo "Instalando Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verificar Docker Compose
echo "Verificando instalación de Docker Compose..."
docker-compose --version

# Instalar PHP 8.1 y las extensiones necesarias
echo "Instalando PHP y extensiones necesarias..."
sudo add-apt-repository ppa:ondrej/php
sudo apt update
sudo apt install -y php8.1 php8.1-cli php8.1-fpm php8.1-mysql php8.1-gd php8.1-mbstring php8.1-xml php8.1-curl php8.1-bcmath php8.1-zip

# Instalar Nginx
echo "Instalando Nginx..."
sudo apt install -y nginx

# Instalar MariaDB
echo "Instalando MariaDB..."
sudo apt install -y mariadb-server
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Configuración de la base de datos para Pterodactyl
echo "Configurando base de datos de Pterodactyl..."
sudo mysql_secure_installation

# Crear base de datos y usuario para Pterodactyl
sudo mysql -u root -p <<EOF
CREATE DATABASE pterodactyl;
CREATE USER 'pterodactyl'@'localhost' IDENTIFIED BY 'strongpassword';  # Cambia la contraseña
GRANT ALL PRIVILEGES ON pterodactyl.* TO 'pterodactyl'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Descargar Pterodactyl Panel
echo "Descargando Pterodactyl Panel..."
cd /var/www
sudo wget https://github.com/pterodactyl/panel/releases/download/v1.0.0/panel.tar.gz
sudo tar -xzvf panel.tar.gz
cd pterodactyl

# Instalar Composer
echo "Instalando Composer..."
sudo apt install -y composer

# Instalar dependencias de PHP con Composer
echo "Instalando dependencias de Pterodactyl..."
sudo composer install --no-dev --optimize-autoloader

# Copiar el archivo .env y configurar la base de datos
echo "Configurando el archivo .env..."
cp .env.example .env
sudo sed -i 's/DB_HOST=127.0.0.1/DB_HOST=127.0.0.1/' .env
sudo sed -i 's/DB_PORT=3306/DB_PORT=3306/' .env
sudo sed -i 's/DB_DATABASE=pterodactyl/DB_DATABASE=pterodactyl/' .env
sudo sed -i 's/DB_USERNAME=root/DB_USERNAME=pterodactyl/' .env
sudo sed -i 's/DB_PASSWORD=secret/DB_PASSWORD=strongpassword/' .env

# Generar la clave de aplicación
echo "Generando clave de aplicación..."
php artisan key:generate --force

# Migrar la base de datos
echo "Migrando la base de datos..."
php artisan migrate --seed

# Configurar los permisos de los archivos
echo "Configurando permisos..."
sudo chown -R www-data:www-data /var/www/pterodactyl/*

# Configurar cronjobs para Pterodactyl
echo "Configurando cronjobs..."
echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" | sudo tee -a /etc/crontab > /dev/null

# Configurar Nginx
echo "Configurando Nginx..."
sudo tee /etc/nginx/sites-available/pterodactyl > /dev/null <<EOF
server {
    listen 80;
    server_name your-domain.com;  # Reemplaza con tu dominio o IP del servidor

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

# Habilitar sitio de Nginx y recargar
echo "Habilitando configuración de Nginx..."
sudo ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
sudo systemctl reload nginx

# Finalizando instalación
echo "¡La instalación de Pterodactyl ha finalizado con éxito!"
echo "Accede al panel a través de tu dominio o IP: http://your-domain.com"
