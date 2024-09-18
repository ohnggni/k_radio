#!/bin/bash

# 설치 옵션 선택
echo "Choose an installation option:"
echo "1) Install both backend(streaming) and frontend(WebUI)"
echo "2) Install backend only"
echo "3) Install frontend only"
echo "4) Do nothing"
read -p "Select an option (1/2/3/4): " INSTALL_OPTION

if [[ "$INSTALL_OPTION" == "4" ]]; then
  echo "No installation selected. Exiting..."
  exit 0
fi

# 사용자로부터 Docker 작업 디렉토리 입력 받기
read -p "Enter the Docker working directory for temporary tasks (e.g., /docker, /home/ubuntu): " DOCKER_DIR

# 디렉토리가 존재하지 않으면 생성
mkdir -p "$DOCKER_DIR"
cd "$DOCKER_DIR"

if [[ "$INSTALL_OPTION" == "1" || "$INSTALL_OPTION" == "2" ]]; then
  # 백엔드 설치
  echo "Starting installation of the streaming server (backend)..."
  read -p "Enter the port for the streaming server (default is 3005): " STREAMING_PORT
  STREAMING_PORT=${STREAMING_PORT:-3005}

  if [ -d "ha_addon" ]; then
    rm -rf ha_addon
  fi
  git clone https://github.com/projectdhs/ha_addon.git
  cd ha_addon/radioha

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

  docker-compose build
  docker-compose up -d
  echo "Backend installation complete."
  cd "$DOCKER_DIR"
fi

if [[ "$INSTALL_OPTION" == "1" || "$INSTALL_OPTION" == "3" ]]; then
  # 프론트엔드 설치
  echo "Starting installation of the WebUI (frontend)..."
  read -p "Enter the streaming server URL (incl. port number) or its reverse proxy URL (e.g., http(s)://yourbackend.address:3005): " BACKEND_ADDRESS
  read -p "Enter the port for the WebUI (default is 3006): " WEBUI_PORT
  WEBUI_PORT=${WEBUI_PORT:-3006}

  # HTTP Basic Authentication 설정
  read -p "Enable HTTP Basic Authentication? (yes/no) [default: no]: " ENABLE_AUTH
  ENABLE_AUTH=${ENABLE_AUTH:-no} # 사용자가 아무것도 입력하지 않으면 기본값 no로 설정
  if [[ "$ENABLE_AUTH" == "yes" ]]; then
    HTTP_AUTH_ENABLED=true
    read -p "Enter HTTP Basic Auth username: " HTTP_AUTH_USER
    read -p "Enter HTTP Basic Auth password: " HTTP_AUTH_PASS
  else
    HTTP_AUTH_ENABLED=false
    HTTP_AUTH_USER=""
    HTTP_AUTH_PASS=""
  fi

  if [ -d "k_radio" ]; then
    rm -rf k_radio
  fi
  git clone https://github.com/ohnggni/k_radio.git
  cd k_radio

  # docker-compose.yml 파일 생성 및 환경 변수 삽입
  cat <<EOF > docker-compose.yml
services:
  frontend:
    container_name: k_radio_frontend
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "${WEBUI_PORT}:80"
    environment:
      - TZ=Asia/Seoul
      - SERVER_IP=${BACKEND_ADDRESS}
      - HTTP_AUTH_ENABLED=${HTTP_AUTH_ENABLED}
      - HTTP_AUTH_USER=${HTTP_AUTH_USER}
      - HTTP_AUTH_PASS=${HTTP_AUTH_PASS}
      - FRONTEND_PORT=${WEBUI_PORT}
    restart: unless-stopped
EOF

  docker-compose build
  docker-compose up -d
  echo "Frontend installation complete."
  cd "$DOCKER_DIR"
fi

# Git 클론 폴더 삭제 여부를 사용자에게 묻기
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

# 설치 완료 메시지
if [[ "$INSTALL_OPTION" == "1" || "$INSTALL_OPTION" == "3" ]]; then
  echo "Installation complete. To access the WebUI, open your browser and go to http://<your-server-ip>:${WEBUI_PORT}."
  echo "For external access, it is recommended to set up a reverse proxy for this address as well."
fi
