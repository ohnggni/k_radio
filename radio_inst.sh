#!/bin/bash

# 사용자로부터 Docker 작업 디렉토리 입력 받기
read -p "Enter the Docker working directory for temporary tasks(e.g., /docker): " DOCKER_DIR
read -p "Enter the backend address for future use(e.g., https://yourbackend.address): " BACKEND_ADDRESS

# 디렉토리가 존재하지 않으면 생성
mkdir -p "$DOCKER_DIR"
cd "$DOCKER_DIR"

# Backend docker 생성
# 1. GitHub 레포지토리 클론
if [ -d "ha_addon" ]; then
  rm -rf ha_addon
fi
git clone https://github.com/projectdhs/ha_addon.git

# 2. 레포지토리 내부로 이동
cd ha_addon/radioha

# 3. Docker Compose 파일 생성
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3005:3005"
    environment:
      - PORT=3005
    restart: unless-stopped
EOF

# 4. Docker 빌드 및 실행
docker-compose build
docker-compose up -d

# Frontend docker 생성
cd "$DOCKER_DIR"

# 1. GitHub 레포지토리 클론
if [ -d "k_radio" ]; then
  rm -rf k_radio
fi
git clone https://github.com/ohnggni/k_radio.git

# 2. 레포지토리 내부로 이동
cd k_radio

# 3. docker-compose.yml에 백엔드 주소 삽입
sed -i "12i\      - SERVER_IP=$BACKEND_ADDRESS" docker-compose.yml

# 4. Docker 빌드 및 실행
docker-compose build
docker-compose up -d

# 5. 사용하지 않는 Git 클론 폴더 삭제
cd "$DOCKER_DIR"
rm -rf ha_addon k_radio

echo "Docker containers have been started, and cloned directories have been removed."
