#!/bin/bash

CONTAINER_NAME="portainer_agent"
IMAGE_NAME="portainer/agent"

echo "================================="
echo "   AUTO UPDATE PORTAINER AGENT  "
echo "================================="

# 1. Ambil versi terbaru (Filter hanya angka x.y.z)
echo "[+] Mengambil versi terbaru dari Docker Hub..."
LATEST_VERSION=$(curl -s "https://registry.hub.docker.com/v2/repositories/$IMAGE_NAME/tags?page_size=100" \
  | grep -Eo '"name":"[0-9]+\.[0-9]+\.[0-9]+"' \
  | awk -F'."' '{print $3}' \
  | sort -V | tail -1)

if [ -z "$LATEST_VERSION" ]; then
    echo "[!] Gagal mengambil versi terbaru. Update dibatalkan."
    exit 1
fi

echo "[+] Versi terbaru: $LATEST_VERSION"

# 2. Cek container lama & ambil Env spesifik (AGENT_SECRET)
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    CURRENT_VERSION=$(docker inspect -f '{{index (split .Config.Image ":") 1}}' $CONTAINER_NAME 2>/dev/null)
    # Ambil AGENT_SECRET jika ada
    AGENT_SECRET=$(docker inspect -f '{{range .Config.Env}}{{if contains "AGENT_SECRET=" .}}{{.}}{{end}}{{end}}' $CONTAINER_NAME | cut -d= -f2)
    
    echo "[+] Versi saat ini: ${CURRENT_VERSION:-unknown}"
else
    echo "[!] Container $CONTAINER_NAME tidak ditemukan. Akan melakukan instalasi bersih."
    CURRENT_VERSION="none"
fi

if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
    echo "[✓] Sudah versi terbaru ($LATEST_VERSION). Tidak ada update."
    exit 0
fi

# 3. Pull image baru
echo "[+] Pulling $IMAGE_NAME:$LATEST_VERSION..."
docker pull $IMAGE_NAME:$LATEST_VERSION

# 4. Hentikan dan hapus container lama
if [ "$CURRENT_VERSION" != "none" ]; then
    echo "[+] Menghapus container lama..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

# 5. Jalankan container baru
echo "[+] Menjalankan Portainer Agent baru..."
# Kita susun command run secara hati-hati
DOCKER_RUN_CMD="docker run -d \
  -p 9001:9001 \
  --name $CONTAINER_NAME \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes"

# Tambahkan AGENT_SECRET ke command jika ditemukan
if [ ! -z "$AGENT_SECRET" ]; then
    DOCKER_RUN_CMD="$DOCKER_RUN_CMD -e AGENT_SECRET=$AGENT_SECRET"
fi

# Eksekusi
eval "$DOCKER_RUN_CMD $IMAGE_NAME:$LATEST_VERSION"

# 6. Bersihkan image lama yang tidak terpakai (dangling)
echo "[+] Membersihkan image lama..."
docker image prune -f --filter "label=io.portainer.agent=true" # Portainer agent biasanya punya label
# Atau cara manual Anda yang sudah diperbaiki:
docker images $IMAGE_NAME --format "{{.ID}} {{.Tag}}" | grep -v "$LATEST_VERSION" | awk '{print $1}' | xargs -r docker rmi -f

echo "====================================="
echo "   UPDATE SELESAI! Versi: $LATEST_VERSION"
echo "====================================="
