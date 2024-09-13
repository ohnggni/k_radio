# Alpine Linux 3.13 베이스 이미지 사용
FROM alpine:3.13 AS base

# 환경 변수 설정
ENV TZ=Asia/Seoul
ENV DEBIAN_FRONTEND=noninteractive

# 기본 패키지 설치
RUN apk add --no-cache \
    tzdata \
    nano \
    bash \
    python3=3.8.15-r0 \
    py3-pip \
    dcron \
    git \
    curl \
    wget \
    nodejs \
    npm \
    fontconfig

# nano 설치 및 설정 추가
RUN git clone https://github.com/scopatz/nanorc.git /tmp/nanorc && \
    mv /tmp/nanorc/*.nanorc /usr/share/nano/
RUN echo "include /usr/share/nano/*.nanorc" >> /root/.nanorc && \
    echo "set tabsize 4" >> /root/.nanorc && \
    echo "set autoindent" >> /root/.nanorc && \
    echo "set linenumbers" >> /root/.nanorc && \
    echo "set smooth" >> /root/.nanorc && \
    echo "set nowrap" >> /root/.nanorc

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

# 프론트엔드 애플리케이션 및 정적 파일 복사
COPY . /frontend
WORKDIR /frontend
RUN npm install && npm install express

RUN chmod 0644 /frontend/crontab && crontab /frontend/crontab && touch /var/log/cron.log

# Cleanup: 설치 후 불필요한 파일 제거
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN apt-get clean

# 한글 로케일 설정
ENV LANG=ko_KR.UTF-8
ENV LANGUAGE=ko_KR:ko
ENV LC_ALL=ko_KR.UTF-8

# dcron을 사용하여 cron 서비스 시작
ENTRYPOINT ["/bin/bash", "-c", "/usr/sbin/crond -f -d 8 && cd /frontend/epg && /usr/bin/python3 -m epg2xml run --xmlfile=/frontend/epg/xmltv.xml & node /frontend/server.js"]
