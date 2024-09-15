#!/bin/bash

# 1. 사용자로부터 Docker 작업 디렉토리 입력 받기
read -p "Enter the Docker working directory for temporary tasks(e.g., /docker, /home/ubuntu): " DOCKER_DIR

# 디렉토리가 존재하지 않으면 생성
mkdir -p "$DOCKER_DIR"
cd "$DOCKER_DIR"

# 2. 스트리밍 서버(백엔드) 설치 시작 안내 및 포트 입력 받기
echo "Starting installation of the streaming server (backend)..."
read -p "Enter the port for the streaming server (default is 3005): " STREAMING_PORT
STREAMING_PORT=${STREAMING_PORT:-3005} # 사용자가 아무것도 입력하지 않으면 기본값 3005로 설정

# Backend docker 생성
# GitHub 레포지토리 클론
if [ -d "ha_addon" ]; then
  rm -rf ha_addon
fi
git clone https://github.com/projectdhs/ha_addon.git

# 레포지토리 내부로 이동
cd ha_addon/radioha

# Docker Compose 파일 생성
cat <<EOF > docker-compose.yml
services:
  backend:
    container_name: k_radio_backend
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "${STREAMING_PORT}:3005"
    environment:
      - PORT=3005
    restart: unless-stopped
EOF

# Docker 빌드 및 실행
docker-compose build
docker-compose up -d

# 3. WebUI 설치 시작 안내 및 백엔드 주소 입력 받기
echo "Streaming server installation complete. Now setting up the WebUI."
echo "For external access, it is recommended to set up a reverse proxy for the streaming server."
read -p "Enter the streaming server URL(incl. port number) or its reverse proxy URL (e.g., http(s)://yourbackend.address:3005): " BACKEND_ADDRESS

# WebUI (프론트엔드) 설치 시작 안내 및 포트 입력 받기
read -p "Enter the port for the WebUI (default is 3006): " WEBUI_PORT
WEBUI_PORT=${WEBUI_PORT:-3006} # 사용자가 아무것도 입력하지 않으면 기본값 3006로 설정

# Frontend docker 생성
cd "$DOCKER_DIR"

# GitHub 레포지토리 클론
if [ -d "k_radio" ]; then
  rm -rf k_radio
fi
git clone https://github.com/ohnggni/k_radio.git

# 레포지토리 내부로 이동
cd k_radio

# docker-compose.yml 파일 생성 및 백엔드 주소 및 포트 삽입
cat <<EOF > docker-compose.yml
services:
  frontend:
    container_name: k_radio_frontend
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "${WEBUI_PORT}:3006"
    environment:
      - TZ=Asia/Seoul
      - SERVER_IP=${BACKEND_ADDRESS}
    restart: unless-stopped
EOF

# Docker 빌드 및 실행
docker-compose build
docker-compose up -d

# 4. 사용하지 않는 Git 클론 폴더 삭제 여부를 사용자에게 묻기
echo "Do you want to delete the cloned directories?"
echo "1) Delete 'ha_addon' only"
echo "2) Delete 'k_radio' only"
echo "3) Delete both 'ha_addon' and 'k_radio'"
echo "4) Keep both directories"
read -p "Select an option (1/2/3/4): " DELETE_OPTION

case "$DELETE_OPTION" in
  1)
    rm -rf ha_addon
    echo "'ha_addon' has been removed."
    ;;
  2)
    rm -rf k_radio
    echo "'k_radio' has been removed."
    ;;
  3)
    rm -rf ha_addon k_radio
    echo "Both 'ha_addon' and 'k_radio' have been removed."
    ;;
  4)
    echo "Both directories have been kept."
    ;;
  *)
    echo "Invalid option. No directories were removed."
    ;;
esac

# 5. WebUI 접속 방법 안내
echo "Installation complete. To access the WebUI, open your browser and go to http://<your-server-ip>:${WEBUI_PORT}."
echo "For external access, it is recommended to set up a reverse proxy for this address as well."
