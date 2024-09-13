# Alpine Linux 베이스 이미지 사용 (초경량)
FROM alpine:3.16 AS base

# 환경 변수 설정
ENV TZ=Asia/Seoul
ENV DEBIAN_FRONTEND=noninteractive

# 기본 패키지 설치
RUN apk add --no-cache \
    tzdata \
    nano \
    bash \
    python3 \
    py3-pip \
    cron \
    git \
    curl \
    nodejs=14.20.0-r0 \
    npm

# 타임존 설정
RUN ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime && \
    echo "Asia/Seoul" > /etc/timezone

# 로케일 설정 (한글 지원)
RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community/ fonts-nanum && \
    apk add --no-cache locales && \
    echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen ko_KR.UTF-8 && \
    export LANG=ko_KR.UTF-8

# pip 업그레이드 및 epg2xml 설치
RUN pip3 install --upgrade pip && \
    pip3 install git+https://github.com/epg2xml/epg2xml.git lxml

# 백엔드 애플리케이션 설치
WORKDIR /app
COPY package*.json /app/
RUN npm install

# 프론트엔드 및 정적 파일 복사
WORKDIR /frontend
COPY . /frontend

# cronjob 파일 설정 및 로그 파일 생성
RUN chmod 0644 /frontend/crontab && crontab /frontend/crontab && touch /var/log/cron.log

# Cleanup: 설치 후 불필요한 파일 제거
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 한글 로케일 설정
ENV LANG=ko_KR.UTF-8
ENV LANGUAGE=ko_KR:ko
ENV LC_ALL=ko_KR.UTF-8

# ENTRYPOINT에서 cron 서비스, 최초epg2xml, Node.js 병행 실행
ENTRYPOINT ["/bin/bash", "-c", "cron && cd /frontend/epg && /usr/bin/python3 -m epg2xml run --xmlfile=/frontend/epg/xmltv.xml && node /app/index.js & node /frontend/server.js"]
