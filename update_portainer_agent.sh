#!/bin/bash

CONTAINER_NAME="portainer_agent"
IMAGE_NAME="portainer/agent"

echo "====================================="
echo "   AUTO UPDATE PORTAINER AGENT (FIX)"
echo "====================================="

# ==============================
#  Ambil versi terbaru (paginate-safe)
# ==============================
echo "[+] Mengambil versi terbaru dari Docker Hub..."

LATEST_VERSION=$(curl -s "https://registry.hub.docker.com/v2/repositories/$IMAGE_NAME/tags?page_size=100" \
  | grep '"name"' \
  | grep -Eo '"[0-9]+\.[0-9]+\.[0-9]+"' \
  | tr -d '"' \
  | sort -V \
  | tail -1)

if [ -z "$LATEST_VERSION" ]; then
    echo "[!] Gagal mengambil versi terbaru. Update dibatalkan."
    exit 1
fi

echo "[+] Versi terbaru: $LATEST_VERSION"

# ==============================
# Ambil versi yang sedang dipakai
# ==============================
CURRENT_VERSION=$(docker inspect -f '{{.Config.Image}}' $CONTAINER_NAME 2>/dev/null | awk -F ":" '{print $2}')

echo "[+] Versi saat ini: ${CURRENT_VERSION:-Tidak ditemukan}"

if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
    echo "[✓] Sudah versi terbaru."
    exit 0
fi

# ==============================
# Ambil environment lama (AGENT_SECRET dll)
# ==============================
ENV_OPTS=$(docker inspect -f '{{range .Config.Env}}{{printf "-e %q " .}}{{end}}' $CONTAINER_NAME 2>/dev/null)

# ==============================
# Stop container lama
# ==============================
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "[+] Menghentikan container lama..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

# ==============================
# Pull versi terbaru
# ==============================
echo "[+] Download image baru..."
docker pull $IMAGE_NAME:$LATEST_VERSION

# ==============================
# Jalankan Portainer Agent
# ==============================
echo "[+] Menjalankan Portainer Agent versi $LATEST_VERSION..."

docker run -d \
  -p 9001:9001 \
  --name $CONTAINER_NAME \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  $ENV_OPTS \
  $IMAGE_NAME:$LATEST_VERSION

if [ $? -ne 0 ]; then
    echo "[!] Container gagal dijalankan!"
    exit 1
fi

echo "====================================="
echo "   UPDATE SELESAI! Versi: $LATEST_VERSION"
echo "====================================="
