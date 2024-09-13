FROM alpine:3.13 AS base

ENV TZ=Asia/Seoul
ENV DEBIAN_FRONTEND=noninteractive

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

RUN ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime && echo "Asia/Seoul" > /etc/timezone

RUN wget https://github.com/naver/nanumfont/releases/download/VER2.5/NanumGothicCoding-2.5.zip -O /tmp/NanumGothicCoding.zip && \
    mkdir -p /usr/share/fonts/nanum && \
    unzip /tmp/NanumGothicCoding.zip -d /usr/share/fonts/nanum && \
    fc-cache -fv && \
    rm -rf /tmp/NanumGothicCoding.zip

RUN pip3 install --upgrade pip && pip3 install git+https://github.com/epg2xml/epg2xml.git lxml

WORKDIR /app
COPY package*.json /app/
RUN npm install

WORKDIR /frontend
COPY . /frontend
RUN npm install

RUN chmod 0644 /frontend/crontab && crontab /frontend/crontab && touch /var/log/cron.log

ENTRYPOINT ["/bin/bash", "-c", "cron && cd /frontend/epg && /usr/bin/python3 -m epg2xml run --xmlfile=/frontend/epg/xmltv.xml && node /app/index.js & node /frontend/server.js"]
