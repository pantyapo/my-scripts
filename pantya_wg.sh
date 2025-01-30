#!/bin/bash

# Запрос параметров
read -p "Введите домен или IP-адрес сервера (например, example.com): " WG_HOST
read -p "Введите пароль для веб-интерфейса wg-easy: " WG_PASSWORD
read -p "Введите имя клиента (например, client1): " CLIENT_NAME

# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Запуск Docker
sudo systemctl start docker
sudo systemctl enable docker

# Установка Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Создание папки для конфигурации
WG_DIR="$HOME/wg-easy"
mkdir -p "$WG_DIR"
cd "$WG_DIR"

# Создание docker-compose.yml
cat <<EOF > docker-compose.yml
version: "3.8"
services:
  wg-easy:
    image: weejewel/wg-easy
    container_name: wg-easy
    environment:
      - WG_HOST=$WG_HOST
      - PASSWORD=$WG_PASSWORD
    volumes:
      - ./config:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
EOF

# Запуск контейнера
sudo docker-compose up -d

# Создание клиента
sudo docker exec -it wg-easy ./create-peer.sh $CLIENT_NAME

# Настройка iptables
sudo docker-compose down
sudo iptables -A INPUT -p tcp --dport 51821 -s 10.0.0.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 51821 -j DROP
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
sudo docker-compose up -d

# Вывод конфигурации клиента
echo "Установка завершена!"
echo "Конфигурация клиента:"
echo "----------------------------------------"
sudo cat $WG_DIR/config/$CLIENT_NAME.conf
echo "----------------------------------------"