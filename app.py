from flask import Flask, render_template, request, Response, abort, send_from_directory
import subprocess
import shlex
import json
import logging
import requests

app = Flask(__name__, static_folder='static')

# 로깅 설정
logging.basicConfig(level=logging.DEBUG)

# radio-list.json 파일에서 URL을 로드
with open('radio-list.json', 'r') as file:
    radio_urls = json.load(file)

# EPG 및 매칭 데이터 로드
EPG_URL = '/epg/xmltv.xml'

# 매칭 JSON 파일 로드
with open('match.json', 'r') as f:
    match_list = json.load(f)
    
# 방송사별 URL을 가져오는 함수
def get_stream_url(key):
    logging.debug(f"Fetching URL for key: {key}")
    if key.startswith('kbs_'):
        return get_kbs_url(key)
    elif key.startswith('mbc_'):
        return get_mbc_url(key)
    elif key.startswith('sbs_'):
        return get_sbs_url(key)
    else:
        return radio_urls.get(key)

def get_kbs_url(key):
    kbs_channels = {
        'kbs_1radio': '21',
        'kbs_3radio': '23',
        'kbs_classic': '24',
        'kbs_cool': '25',
        'kbs_happy': '22'
    }
    channel_code = kbs_channels.get(key)
    if not channel_code:
        return None

    try:
        response = requests.get(f'https://cfpwwwapi.kbs.co.kr/api/v1/landing/live/channel_code/{channel_code}',
                                headers={'User-Agent': 'Mozilla/5.0', 'referer': 'https://onair.kbs.co.kr/'})
        response.raise_for_status()
        data = response.json()
        for item in data.get('channel_item', []):
            if item.get('media_type') == 'radio':
                url = item.get('service_url')
                logging.debug(f"Fetched KBS URL: {url}")
                return url
    except Exception as e:
        logging.error(f"KBS URL fetch error: {e}")
    return None

def get_mbc_url(key):
    mbc_channels = {
        'mbc_fm4u': 'mfm',
        'mbc_fm': 'sfm'
    }
    channel_code = mbc_channels.get(key)
    if not channel_code:
        return None

    try:
        response = requests.get(f'https://sminiplay.imbc.com/aacplay.ashx?agent=webapp&channel={channel_code}&callback=jarvis.miniInfo.loadOnAirComplete',
                                headers={'User-Agent': 'Mozilla/5.0', 'Referer': 'http://mini.imbc.com/'})
        response.raise_for_status()
        data = response.text
        url = 'https://' + data.split('"https://')[1].split('"')[0]
        logging.debug(f"Fetched MBC URL: {url}")
        return url
    except Exception as e:
        logging.error(f"MBC URL fetch error: {e}")
    return None

def get_sbs_url(key):
    sbs_channels = {
        'sbs_power': ['powerfm', 'powerpc'],
        'sbs_love': ['lovefm', 'lovepc']
    }
    channel_info = sbs_channels.get(key)
    if not channel_info:
        return None

    try:
        headers = {
            'Host': 'apis.sbs.co.kr',
            'Connection': 'keep-alive',
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_16_0) AppleWebKit/537.36 (KHTML, like Gecko) GOREALRA/1.2.1 Chrome/85.0.4183.121 Electron/10.1.3 Safari/537.36',
            'Accept': '*/*',
            'Origin': 'https://gorealraplayer.radio.sbs.co.kr',
            'Sec-Fetch-Site': 'same-site',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Dest': 'empty',
            'Referer': 'https://gorealraplayer.radio.sbs.co.kr/main.html?v=1.2.1',
            'Accept-Encoding': 'gzip, deflate, br',
            'Accept-Language': 'ko',
            'If-None-Match': 'W/"134-0OoLHiGF4IrBKYLjJQzxNs0/11M"'
        }

        response = requests.get(
            f'https://apis.sbs.co.kr/play-api/1.0/livestream/{channel_info[1]}/{channel_info[0]}?protocol=hls&ssl=Y',
            headers=headers
        )
        logging.debug(f"SBS API Response status code: {response.status_code}")
        response.raise_for_status()

        # 응답의 텍스트를 그대로 반환
        url = response.text.strip()
        logging.debug(f"Fetched SBS URL: {url}")
        return url

    except requests.exceptions.HTTPError as e:
        logging.error(f"SBS URL fetch HTTP error: {e}")
    except requests.exceptions.RequestException as e:
        logging.error(f"SBS URL fetch request error: {e}")
    except ValueError as e:
        logging.error(f"SBS URL fetch error (Invalid response): {e}")
        logging.debug(f"Response content: {response.text}")  # 오류 발생 시 실제 응답 내용을 기록
    return None

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/radio')
def stream_radio():
    key = request.args.get('keys')
    token = request.args.get('token')
    atype = request.args.get('atype', '0')  # 기본값을 '0'으로 설정

    if not key or token != 'homeassistant':
        abort(403)  # 올바르지 않은 접근

    url = get_stream_url(key)
    if not url:
        abort(404)  # URL을 찾을 수 없는 경우

    return generate_stream(url, atype)  # atype 매개변수를 추가하여 호출

def generate_stream(url, atype):
    # 각 atype에 따른 비트레이트 설정
    audio_bitrates = {
        '0': '256k',
        '1': '192k',
        '2': '128k',
        '3': '96k',
        '4': '48k'
    }
    # 선택한 atype에 해당하는 비트레이트를 사용, 기본값은 '256k'
    bitrate = audio_bitrates.get(atype, '256k')

    # 수정된 FFmpeg 명령어
    ffmpeg_command = f"ffmpeg -i {url} -c:a aac -b:a {bitrate} -f adts -"

    logging.debug(f"Executing FFmpeg command: {ffmpeg_command}")

    # subprocess를 실행하여 FFmpeg를 호출하고, 버퍼 크기를 0으로 설정
    process = subprocess.Popen(
        shlex.split(ffmpeg_command),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        bufsize=0  # 버퍼 크기 0으로 설정
    )

    def generate():
        try:
            while True:
                output = process.stdout.read(1024)
                if not output:
                    break
                yield output
        except Exception as e:
            logging.error(f"Error while streaming: {e}")
        finally:
            process.kill()

    def generate_with_error():
        yield from generate()
        stderr_output = process.stderr.read().decode('utf-8')
        if stderr_output:
            logging.error(f"FFmpeg stderr: {stderr_output}")

    response = Response(generate_with_error(), content_type='audio/aac')  # 브라우저 호환을 위한 AAC 형식
    response.headers.add('Access-Control-Allow-Origin', '*')  # CORS 헤더 추가
    return response

# match.json 파일 제공
@app.route('/match.json')
def serve_match_json():
    return send_from_directory('/app', 'match.json')

# xmltv.xml 파일 제공
@app.route('/epg/xmltv.xml')
def serve_epg_file():
    return send_from_directory('/epg', 'xmltv.xml')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3005, debug=True)
