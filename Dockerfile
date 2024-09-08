# Python 3.10 이미지 사용
FROM python:3.10-slim

# 필요한 패키지 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libssl-dev \
    libavcodec-extra \
    iputils-ping \
    dnsutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 필요한 Python 패키지 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Flask 애플리케이션 코드 복사
COPY . .

EXPOSE 3005

CMD ["python", "app.py"]