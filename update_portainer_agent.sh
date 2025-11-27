#!/bin/bash

CONTAINER_NAME="portainer_agent"
IMAGE_NAME="portainer/agent"

echo "====================================="
echo "     AUTO UPDATE PORTAINER AGENT"
echo "====================================="

# ==============================
#  Ambil versi terbaru dari Docker Hub
# ==============================
echo "[+] Mengambil versi terbaru dari Docker Hub..."

LATEST_VERSION=$(curl -s https://registry.hub.docker.com/v2/repositories/$IMAGE_NAME/tags \
  | grep '"name"' \
  | grep -v "latest" \
  | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' \
  | sort -V \
  | tail -1)

if [ -z "$LATEST_VERSION" ]; then
    echo "[!] Gagal mengambil versi terbaru. Update dibatalkan."
    exit 1
fi

echo "[+] Versi terbaru ditemukan: $LATEST_VERSION"

# ==============================
#  Ambil versi yang sedang dipakai
# ==============================
CURRENT_VERSION=$(docker ps --format '{{.Image}}' | grep $IMAGE_NAME | awk -F ":" '{print $2}')

echo "[+] Versi saat ini: ${CURRENT_VERSION:-Tidak ditemukan}"

if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
    echo "[✓] Sudah menggunakan versi terbaru. Tidak perlu update."
    exit 0
fi

# ==============================
#  Hentikan container jika ada
# ==============================
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo "[+] Menghentikan container lama..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
else
    echo "[!] Container lama tidak ditemukan. Lewati."
fi

# ==============================
#  Hapus versi lama jika ada
# ==============================
if docker images | grep -q "$IMAGE_NAME"; then
    echo "[+] Menghapus image versi lama..."
    docker rmi $(docker images $IMAGE_NAME -q)
else
    echo "[!] Image lama tidak ada. Lewati."
fi

# ==============================
#  Jalankan versi terbaru
# ==============================
echo "[+] Menjalankan Portainer Agent versi $LATEST_VERSION..."

docker run -d \
  -p 9001:9001 \
  --name $CONTAINER_NAME \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  $IMAGE_NAME:$LATEST_VERSION

echo ""
echo "====================================="
echo "   UPDATE SELESAI!"
echo "   Portainer Agent sekarang versi $LATEST_VERSION"
echo "====================================="
