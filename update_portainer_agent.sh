#!/bin/bash

CONTAINER_NAME="portainer_agent"
IMAGE_NAME="portainer/agent"

echo "================================="
echo "   AUTO UPDATE PORTAINER AGENT  "
echo "================================="

# ==============================
# Ambil versi terbaru (Filter diperbaiki)
# ==============================
echo "[+] Mengambil versi terbaru dari Docker Hub..."

# Menggunakan grep untuk pola angka x.y.z dan cut untuk mengambil nilainya saja
LATEST_VERSION=$(curl -s "https://registry.hub.docker.com/v2/repositories/$IMAGE_NAME/tags?page_size=100" \
  | grep -Eo '"name":"[0-9]+\.[0-9]+\.[0-9]+"' \
  | sort -V \
  | tail -1 \
  | cut -d'"' -f4)

if [ -z "$LATEST_VERSION" ]; then
    echo "[!] Gagal mengambil versi terbaru. Update dibatalkan."
    exit 1
fi

echo "[+] Versi terbaru: $LATEST_VERSION"

# ==============================
# Ambil versi yang sedang berjalan
# ==============================
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    CURRENT_VERSION=$(docker inspect -f '{{.Config.Image}}' $CONTAINER_NAME 2>/dev/null | awk -F ":" '{print $2}')
    echo "[+] Versi saat ini: $CURRENT_VERSION"
else
    echo "[!] Container $CONTAINER_NAME tidak ditemukan. Akan melakukan instalasi baru."
    CURRENT_VERSION="none"
fi

if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
    echo "[✓] Sudah versi terbaru ($LATEST_VERSION)."
    exit 0
fi

# ==============================
# Simpan environment lama (jika ada)
# ==============================
ENV_OPTS=""
if [ "$CURRENT_VERSION" != "none" ]; then
    ENV_OPTS=$(docker inspect -f '{{range .Config.Env}}{{printf "-e %q " .}}{{end}}' $CONTAINER_NAME 2>/dev/null)
fi

# ==============================
# Hentikan & Hapus container lama
# ==============================
if [ "$CURRENT_VERSION" != "none" ]; then
    echo "[+] Menghentikan dan menghapus container lama..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

# ==============================
# Pull & Jalankan versi terbaru
# ==============================
echo "[+] Pulling $IMAGE_NAME:$LATEST_VERSION..."
docker pull $IMAGE_NAME:$LATEST_VERSION

echo "[+] Menjalankan Portainer Agent versi $LATEST_VERSION..."
docker run -d \
  -p 9001:9001 \
  --name $CONTAINER_NAME \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  $ENV_OPTS \
  $IMAGE_NAME:$LATEST_VERSION

if [ $? -eq 0 ]; then
    # ==============================
    # Bersihkan image lama
    # ==============================
    echo "[+] Membersihkan image lama..."
    docker image prune -f --filter "label=io.portainer.agent=true" > /dev/null 2>&1
    # Pembersihan manual tambahan
    docker images $IMAGE_NAME --format "{{.ID}} {{.Tag}}" | grep -v "$LATEST_VERSION" | awk '{print $1}' | xargs -r docker rmi -f > /dev/null 2>&1
    
    echo "====================================="
    echo "   UPDATE BERHASIL! Versi: $LATEST_VERSION"
    echo "====================================="
else
    echo "[!] Terjadi kesalahan saat menjalankan container baru."
    exit 1
fi
