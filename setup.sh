#!/bin/bash

set -e

echo "=================================================="
echo "        VPNサーバー 自動作成スクリプト       "
echo "=================================================="
echo "これからいくつか質問をします。画面の指示に従って入力してください。"
echo ""

# IPアドレスの取得
SERVER_IP=$(curl -s inet-ip.info || curl -s ifconfig.me)

if [ -z "$SERVER_IP" ]; then
    while [ -z "$SERVER_IP" ]; do
        read -p "「数字の塊」が見つかりませんでした。もう一度入力してください: " SERVER_IP < /dev/tty
    done
else
    echo "「数字の塊」を自動で見つけました: $SERVER_IP"
fi

# パスワードの入力（パイプライン対策）
while [ -z "$RAW_PASSWORD" ]; do
    read -p "好きなパスワードを決めてください: " RAW_PASSWORD < /dev/tty
    if [ -z "$RAW_PASSWORD" ]; then
        echo "なにも入力されてないようです...何か決めてください！"
    fi
done

echo ""
echo " 設定を受け付けました！作成を始めます。数分かかります..."
echo "=================================================="
echo ""

echo "サーバーをサクサク動くようにします"
# すでにスワップファイルが存在し有効化されているかチェック
if swapon --show | grep -q '/swapfile'; then
    echo "すでにサクサク用の設定ができています。いいですね！"
else
    sudo swapoff /swapfile 2>/dev/null || true
    sudo fallocate -l 4G /swapfile > /dev/null
    sudo chmod 600 /swapfile > /dev/null
    sudo mkswap /swapfile > /dev/null
    sudo swapon /swapfile > /dev/null
    grep -qxF '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
fi

echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf > /dev/null
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf > /dev/null
sudo sysctl -p > /dev/null

echo "サーバーを更新し、必要なアプリを入れます"
sudo apt-get update -y > /dev/null
sudo apt-get install -y curl iptables-persistent > /dev/null

# Docker本体とプラグインのインストール
curl -fsSL https://get.docker.com | sh > /dev/null
sudo apt-get install -y docker-compose-plugin > /dev/null

echo "パスワードの暗号化をします"
sudo docker pull ghcr.io/wg-easy/wg-easy > /dev/null

# 成功するまで無限ループ
while true; do
    # ハッシュの生成を試みる
    RAW_HASH=$(sudo docker run --rm ghcr.io/wg-easy/wg-easy password "$RAW_PASSWORD" 2>/dev/null | grep "PASSWORD_HASH=" | cut -d'=' -f2-)
    
    # $ を $$ にエスケープ
    ESCAPED_HASH=$(echo "$RAW_HASH" | sed 's/\$/$$/g')

    # エスケープ後のハッシュが空でなければ、ループを抜ける
    if [ -n "$ESCAPED_HASH" ]; then
        break
    fi

    echo "Dockerの準備が整うのを待っています...（3秒後に再試行）"
    sleep 3
done
mkdir -p ~/wg-easy && cd ~/wg-easy

echo "VPNの設定をします"
cat << \EOF > docker-compose.yml
services:
  wg-easy:
    environment:
      - LANG=ja
      - WG_HOST=__SERVER_IP__
      - PASSWORD_HASH=__ESCAPED_HASH__
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

sed -i "s|__SERVER_IP__|${SERVER_IP}|g" docker-compose.yml
sed -i "s|__ESCAPED_HASH__|${ESCAPED_HASH}|g" docker-compose.yml

sudo netfilter-persistent save > /dev/null

echo "VPNを起動します"
sudo docker compose up -d

echo ""
echo "=================================================="
echo " おめでとうございます!VPNサーバーができました！ "
echo "=================================================="
echo " 設定画面）: http://${SERVER_IP}:51821"
echo " パスワード: (先ほど入力したパスワード)"
echo "=================================================="
