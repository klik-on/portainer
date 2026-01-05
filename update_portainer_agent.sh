#!/bin/bash

CONTAINER_NAME="portainer_agent"
IMAGE_NAME="portainer/agent"

echo "================================="
echo "   AUTO UPDATE PORTAINER AGENT  "
echo "================================="

# ==============================
# Ambil versi terbaru
# ==============================
echo "[+] Mengambil versi terbaru dari Docker Hub..."

LATEST_VERSION=$(curl -s "https://registry.hub.docker.com/v2/repositories/$IMAGE_NAME/tags?page_size=100" \
  | grep -Eo '"name":"[0-9]+\.[0-9]+\.[0-9]+"' \
  | head -1 \
  | awk -F'."' '{print $3}')

if [ -z "$LATEST_VERSION" ]; then
    echo "[!] Gagal mengambil versi terbaru. Update dibatalkan."
    exit 1
fi

echo "[+] Versi terbaru: $LATEST_VERSION"

# ==============================
# Ambil versi yang sedang berjalan
# ==============================
CURRENT_VERSION=$(docker inspect -f '{{.Config.Image}}' $CONTAINER_NAME 2>/dev/null | awk -F ":" '{print $2}')

echo "[+] Versi saat ini: ${CURRENT_VERSION:-Tidak ditemukan}"

if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
    echo "[✓] Sudah versi terbaru. Menghapus image lama..."

    OLD_IMAGES=$(docker images $IMAGE_NAME --format "{{.ID}} {{.Tag}}" \
      | grep -v "$LATEST_VERSION" \
      | awk '{print $1}')

    if [ -z "$OLD_IMAGES" ]; then
        echo "[✓] Tidak ada image lama."
    else
        echo "$OLD_IMAGES" | xargs -r docker rmi -f
        echo "[✓] Image lama berhasil dibersihkan."
    fi

    exit 0
fi

# ==============================
# Simpan environment lama
# ==============================
ENV_OPTS=$(docker inspect -f '{{range .Config.Env}}{{printf "-e %q " .}}{{end}}' $CONTAINER_NAME 2>/dev/null)

# ==============================
# Hentikan container lama
# ==============================
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "[+] Menghentikan container lama..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

# ==============================
# Download versi terbaru
# ==============================
echo "[+] Pull image baru..."
docker pull $IMAGE_NAME:$LATEST_VERSION

# ==============================
# Jalankan container baru
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

# ==============================
# Hapus image lama (Setelah container baru jalan)
# ==============================
echo "[+] Menghapus image versi lama..."
OLD_IMAGES=$(docker images $IMAGE_NAME --format "{{.ID}} {{.Tag}}" \
  | grep -v "$LATEST_VERSION" \
  | awk '{print $1}')

if [ ! -z "$OLD_IMAGES" ]; then
    echo "$OLD_IMAGES" | xargs -r docker rmi -f
    echo "[✓] Image lama berhasil dihapus."
fi

echo "====================================="
echo "   UPDATE SELESAI! Versi: $LATEST_VERSION"
echo "====================================="
