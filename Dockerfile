# Stage 1: Base image using Alpine Linux 3.13
FROM alpine:3.13 AS base

# Set environment variables
ENV TZ=Asia/Seoul
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
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
    fontconfig \
    nginx \
    apache2-utils

# Configure nano editor
RUN git clone https://github.com/scopatz/nanorc.git /tmp/nanorc && \
    mkdir -p /usr/share/nano/ && \
    cp /tmp/nanorc/*.nanorc /usr/share/nano/ && \
    rm -rf /tmp/nanorc

RUN echo 'include "/usr/share/nano/*.nanorc"' >> /root/.nanorc && \
    echo 'set tabsize 4' >> /root/.nanorc && \
    echo 'set autoindent' >> /root/.nanorc && \
    echo 'set linenumbers' >> /root/.nanorc && \
    echo 'set nowrap' >> /root/.nanorc

# Timezone setup
RUN ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime && echo "Asia/Seoul" > /etc/timezone

# Install Korean fonts
RUN wget https://github.com/naver/nanumfont/releases/download/VER2.5/NanumGothicCoding-2.5.zip -O /tmp/NanumGothicCoding.zip && \
    mkdir -p /usr/share/fonts/nanum && \
    unzip /tmp/NanumGothicCoding.zip -d /usr/share/fonts/nanum && \
    fc-cache -fv && \
    rm -rf /tmp/NanumGothicCoding.zip

# Upgrade pip and install epg2xml
RUN pip3 install --upgrade pip && pip3 install git+https://github.com/epg2xml/epg2xml.git lxml

# Copy frontend application and install dependencies
COPY . /frontend
WORKDIR /frontend
RUN npm install && npm install express

# Set crontab and log
RUN chmod 0644 /frontend/crontab && crontab /frontend/crontab && touch /var/log/cron.log

# Cleanup after installation
RUN rm -rf /var/cache/apk/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure Korean locale
ENV LANG=ko_KR.UTF-8
ENV LANGUAGE=ko_KR:ko
ENV LC_ALL=ko_KR.UTF-8

# 기본 사용자와 비밀번호 파일을 생성
RUN touch /etc/nginx/.htpasswd

# Nginx configuration template setup
RUN apk add --no-cache gettext && \
    echo 'log_format simple_logs '\''ACCESS: remote_addr=$remote_addr | user=$remote_user | time=$time_local | request="$request" | status=$status'\'';' > /etc/nginx/http.d/default.conf.template && \
    echo 'access_log /var/log/nginx/access.log simple_logs;' >> /etc/nginx/http.d/default.conf.template && \
    echo 'server {' >> /etc/nginx/http.d/default.conf.template && \
    echo '    listen 80;' >> /etc/nginx/http.d/default.conf.template && \
    echo '    server_name localhost;' >> /etc/nginx/http.d/default.conf.template && \
    echo '    location / {' >> /etc/nginx/http.d/default.conf.template && \
    echo '        root /frontend;' >> /etc/nginx/http.d/default.conf.template && \
    echo '        autoindex on;' >> /etc/nginx/http.d/default.conf.template && \
    echo '        proxy_pass http://127.0.0.1:3006;' >> /etc/nginx/http.d/default.conf.template && \
    echo '        proxy_set_header Host $host;' >> /etc/nginx/http.d/default.conf.template && \
    echo '        proxy_set_header X-Real-IP $remote_addr;' >> /etc/nginx/http.d/default.conf.template && \
    echo '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' >> /etc/nginx/http.d/default.conf.template && \
    echo '        proxy_set_header X-Forwarded-Proto $scheme;' >> /etc/nginx/http.d/default.conf.template && \
    echo '        #AUTH_BASIC_PLACEHOLDER#' >> /etc/nginx/http.d/default.conf.template && \
    echo '        access_log /var/log/nginx/access.log simple_logs;' >> /etc/nginx/http.d/default.conf.template && \
    echo '    }' >> /etc/nginx/http.d/default.conf.template && \
    echo '}' >> /etc/nginx/http.d/default.conf.template

# Create Nginx PID directory
RUN mkdir -p /run/nginx

# Entry point: Dynamically create .htpasswd and Nginx configuration file
ENTRYPOINT ["/bin/sh", "-c", "\
    if [ \"$HTTP_AUTH_ENABLED\" = \"true\" ]; then \
        htpasswd -bc /etc/nginx/.htpasswd $HTTP_AUTH_USER $HTTP_AUTH_PASS; \
        sed 's/#AUTH_BASIC_PLACEHOLDER#/auth_basic \"Restricted Access\";\\nauth_basic_user_file \\/etc\\/nginx\\/.htpasswd;/' /etc/nginx/http.d/default.conf.template | \
        sed 's/127.0.0.1:3006/127.0.0.1:'\"$FRONTEND_PORT\"'/' > /etc/nginx/conf.d/default.conf; \
    else \
        sed 's/#AUTH_BASIC_PLACEHOLDER#//' /etc/nginx/http.d/default.conf.template | \
        sed 's/127.0.0.1:3006/127.0.0.1:'\"$FRONTEND_PORT\"'/' > /etc/nginx/conf.d/default.conf; \
    fi && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    nginx && /usr/sbin/crond -f -d 0 > /dev/null 2>&1 & cd /frontend/epg && /usr/bin/python3 -m epg2xml run --xmlfile=/frontend/epg/xmltv.xml & node /frontend/server.js"]
