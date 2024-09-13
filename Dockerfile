# Alpine Linux 3.13 베이스 이미지 사용
FROM alpine:3.13 AS base

# 환경 변수 설정
ENV TZ=Asia/Seoul
ENV DEBIAN_FRONTEND=noninteractive

# 기본 패키지 설치
RUN apk add --no-cache \
    tzdata \ # 타임존 데이터 설치
    nano \ # 편집기 설치
    bash \ # 쉘 설치
    python3=3.9.1-r1 \ # Python 3.9 설치
    py3-pip \ # pip 설치
    cronie \ # cron 설치
    git \ # Git 설치
    curl \ # cURL 설치
    wget \ # wget 설치
    nodejs \ # Node.js 설치
    npm \ # npm 설치
    fontconfig # 폰트 설정 도구 설치

# 타임존 설정
RUN ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime && echo "Asia/Seoul" > /etc/timezone

# 한글 폰트 설치
RUN wget https://github.com/naver/nanumfont/releases/download/VER2.5/NanumGothicCoding-2.5.zip -O /tmp/NanumGothicCoding.zip && \
    mkdir -p /usr/share/fonts/nanum && \
    unzip /tmp/NanumGothicCoding.zip -d /usr/share/fonts/nanum && \
    fc-cache -fv && \
    rm -rf /tmp/NanumGothicCoding.zip

# pip 업그레이드 및 epg2xml 설치
RUN pip3 install --upgrade pip && pip3 install git+https://github.com/epg2xml/epg2xml.git lxml

# 백엔드 애플리케이션 설치
WORKDIR /app
COPY package*.json /app/
RUN npm install && npm install express

# 프론트엔드 및 정적 파일 복사
WORKDIR /frontend
COPY . /frontend

# 필요한 파일 복사
COPY ./server.js /frontend/server.js 
COPY ./epg /frontend/epg  

# cronjob 파일 설정 및 로그 파일 생성
RUN chmod 0644 /frontend/crontab && crontab /frontend/crontab && touch /var/log/cron.log

# Cleanup: 설치 후 불필요한 파일 제거
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 한글 로케일 설정
ENV LANG=ko_KR.UTF-8
ENV LANGUAGE=ko_KR:ko
ENV LC_ALL=ko_KR.UTF-8

# ENTRYPOINT에서 cron 서비스, 최초epg2xml, Node.js 병행 실행
ENTRYPOINT ["/bin/bash", "-c", "crond && cd /frontend/epg && /usr/bin/python3 -m epg2xml run --xmlfile=/frontend/epg/xmltv.xml && node /app/index.js & node /frontend/server.js"]
