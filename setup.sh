#!/bin/bash

set -e

echo "=================================================="
echo "       　VPNサーバー 自動作成スクリプト       "
echo "=================================================="
echo "これからいくつか質問をします。画面の指示に従って入力してください。"
echo ""

while [ -z "$SERVER_IP" ]; do
    read -p "「IPアドレス」を入力してエンターを押してください: " SERVER_IP
    if [ -z "$SERVER_IP" ]; then
        echo "間違っているようです...ヒント:数字とピリオドの塊です！"
    fi
done

while [ -z "$VPN_PASSWORD" ]; do
    read -s -p "好きなパスワードを決めてください" VPN_PASSWORD
    echo "" # 改行用
    if [ -z "$VPN_PASSWORD" ]; then
        echo "なにも入力されてないようです...何か決めてください！"
    fi
done

echo ""
echo " 設定を受け付けました！作成を始めます。数分かかります..."
echo "=================================================="
echo ""

echo "サーバーをサクサク動くようにします"

sudo fallocate -l 4G /swapfile > /dev/null
sudo chmod 600 /swapfile > /dev/null
sudo mkswap /swapfile > /dev/null
sudo swapon /swapfile > /dev/null
sudo cp /etc/fstab /etc/fstab.bak > /dev/null
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
sudo sysctl vm.swappiness=10 > /dev/null
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null
sudo sysctl vm.vfs_cache_pressure=50 > /dev/null
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf > /dev/null
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
sudo sysctl -p > /dev/null

echo "サーバーを更新します"

sudo apt-get update -y > /dev/null
sudo apt-get install -y curl > /dev/null
curl -fsSL https://get.docker.com | sh > /dev/null

mkdir -p ~/wg-easy && cd ~/wg-easy

echo "VPNの設定をします"

cat << EOF > docker-compose.yml
services:
  wg-easy:
    environment:
      - LANG=ja
      - WG_HOST=${SERVER_IP}
      - PASSWORD=${VPN_PASSWORD}
      - PORT=51821
      - WG_PORT=51820
    image: ghcr.io/wg-easy/wg-easy
    container_name: wg-easy
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
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
EOF

echo "ネットにアクセスできるようにします"

sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
if command -v netfilter-persistent &> /dev/null; then
    sudo netfilter-persistent save > /dev/null
fi

echo "VPNを起動します"

sudo docker compose up -d

echo ""
echo "=================================================="
echo "　おめでとうございます!VPNサーバーができました！　"
echo "=================================================="
echo " 設定画面）: http://${SERVER_IP}:51821"
echo " パスワード: (先ほど入力したパスワード)"
echo "=================================================="
