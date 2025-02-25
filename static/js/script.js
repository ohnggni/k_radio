// 오디오 요소와 재생 상태 요소 가져오기
const audioElement = document.getElementById('globalAudioPlayer');
const playingStatusElement = document.querySelector('.playing-status');
const playingChannelElement = document.getElementById('playingChannel');
const playingLogoElement = document.getElementById('playingLogo');

// 현재 선택된 채널과 음질 상태 저장
let currentChannelKey = '';  // 현재 재생 중인 채널의 key 값
let currentChannelTitle = ''; // 현재 재생 중인 채널의 title 값
let currentArtist = 'Ohnggni Radio'; // 기본 artist 설정
let currentImage = ''; // 현재 이미지 설정
let currentQuality = '0'; // 기본 음질은 256k로 설정

// 음질 선택 변경 시 이벤트 핸들러
document.getElementById('qualitySelect').addEventListener('change', function (event) {
    currentQuality = event.target.value; // 현재 선택된 음질 업데이트
    if (currentChannelKey) {
        // 현재 재생 중인 채널이 있는 경우, 새 음질로 다시 재생, SERVER_IP는 server.js(도커환경변수에서부터)에서 사전에 지정
        changeAudioSource(`${SERVER_IP}/radio?keys=${currentChannelKey}&token=homeassistant&atype=${currentQuality}`, currentChannelKey, currentChannelTitle, currentArtist, currentImage);
    }
});


// 유지 및 수정: 채널 로고를 클릭할 때 호출되는 함수
function onChannelLogoClick(key, title, artist, image) {
    currentChannelKey = key;  // 클릭된 채널의 key 값으로 설정
    currentChannelTitle = title; // 클릭된 채널의 title 값으로 설정
    currentArtist = artist; // 클릭된 채널의 artist 값으로 설정
    currentImage = image; // 클릭된 채널의 이미지 값으로 설정
    changeAudioSource(`${SERVER_IP}/radio?keys=${key}&token=homeassistant&atype=${currentQuality}`, key, title, artist, image); // SERVER_IP는 server.js(도커환경변수에서부터)에서 사전에 지정
    
    // 추가: EPG 정보 업데이트 함수 호출
    if (typeof displayEPGInfo === 'function') {
        displayEPGInfo(key); // epg.js의 displayEPGInfo 호출
    } else {
        console.warn('displayEPGInfo function not found');
    }
}

// 채널 URL을 설정하고 재생을 처리하는 함수
function changeAudioSource(src, key, title, artist, image) {
    console.log('Changing audio source to:', src);
    audioElement.pause(); // 기존 재생 중지
    audioElement.src = src; // 새로운 소스 설정

    // 이미지 URL 유효성 검사 후 Media Session 메타데이터 설정
    if (image && typeof image === 'string' && image.trim() !== '') {
        setMediaSessionData(title, artist, image); // Media Session 메타데이터 설정
    } else {
        console.warn('Invalid image URL for MediaSession:', image);
        image = ''; // 이미지가 유효하지 않을 경우 빈 문자열로 설정
    }

    // 재생 상태와 로고, 채널 이름 업데이트
    playingChannelElement.textContent = title;
    //playingChannelElement.style.fontWeight = 'bold'; // Channel명을 bold로 설정
    playingLogoElement.src = image;
    playingStatusElement.textContent = "playing"; // Play 기호
    playingStatusElement.style.display = 'inline'; // "재생 중" 문구 보이기

    // 현재 재생 상태 저장
    currentChannelKey = key;  // URL의 key 값으로 설정
    currentChannelTitle = title; // 채널의 title 값으로 설정
    currentArtist = artist; // 채널의 artist 값으로 설정

    audioElement.play().then(() => {
        console.log('오디오 재생 성공');
    }).catch((error) => {
        console.error('재생 시도 실패:', error);
    });
}

// Media Session 메타데이터 설정 함수
function setMediaSessionData(title, artist, image) {
    if ('mediaSession' in navigator) {
        navigator.mediaSession.metadata = new MediaMetadata({
            title: title,
            artist: artist,
            artwork: [
                { src: image, sizes: '48x48', type: 'image/png' }
            ]
        });
    }
}

// 오디오 재생이 멈췄을 때 상태 업데이트
audioElement.addEventListener('pause', function () {
    playingStatusElement.innerHTML = "&nbsp;paused"; // Pause 기호로 업데이트
    playingStatusElement.style.display = 'inline'; // 상태 텍스트 보이기
});

// 오디오 재생이 시작되었을 때 상태 업데이트
audioElement.addEventListener('play', function () {
    playingStatusElement.innerHTML = "&nbsp;playing"; // Play 기호로 업데이트
    playingStatusElement.style.display = 'inline'; // 상태 텍스트 보이기
});

// 재생 시도 실패 시 오류 메시지 출력
audioElement.addEventListener('error', function () {
    console.error('오디오 재생 오류 발생');
});

// 새로 고침 버튼 클릭 시 페이지 새로 고침
function reloadPage() {
    location.reload(); // 페이지 새로 고침
}

// URL 파라미터(query string) 대응 코드
document.addEventListener("DOMContentLoaded", function () {
    const player = document.querySelector("#globalAudioPlayer");
    const airplayButton = document.querySelector("#airplay-button");
    const playModal = document.getElementById("playModal");
    const playButton = document.getElementById("playButton");
    const table = document.querySelector(".table");

    let isAirPlayAvailable = false;
    let channelId = null;

    // 🎛 AirPlay 버튼 활성화
    player.addEventListener("webkitplaybacktargetavailabilitychanged", event => {
        if (event.availability === "available") {
            isAirPlayAvailable = true;
        }
    });

    airplayButton.addEventListener("click", () => {
        if (isAirPlayAvailable) {
            player.webkitShowPlaybackTargetPicker();
        }
    });

    // 🔎 URL에서 채널 파라미터 가져오기
    function getQueryParam(name) {
        const urlParams = new URLSearchParams(window.location.search);
        return urlParams.get(name);
    }

    channelId = getQueryParam("channel");

    // 📡 채널별 정보 매핑
    const channelMap = {
        "ebsfm": ["ebsfm", "EBS", "Ohnggni Radio", "/static/images/ebs_fm.png"],
        "cbs_music_fm": ["cbs_music_fm", "CBS Music", "Ohnggni Radio", "/static/images/cbs_music.png"],
        "kbs_classic": ["kbs_classic", "KBS Classic", "Ohnggni Radio", "/static/images/kbs_classic.png"],
        "kbs_1radio": ["kbs_1radio", "KBS1", "Ohnggni Radio", "/static/images/kbs1.png"],
        "ytn": ["ytn", "YTN", "Ohnggni Radio", "/static/images/ytn.png"],
        "tbsfm": ["tbsfm", "TBS", "Ohnggni Radio", "/static/images/tbs.png"],
        "tbnfm": ["tbnfm", "TBN", "Ohnggni Radio", "/static/images/tbn.png"],
        "ifm": ["ifm", "iTV", "Ohnggni Radio", "/static/images/itv.png"],
        "kbs_happy": ["kbs_happy", "KBS Happy", "Ohnggni Radio", "/static/images/kbs_happy.png"],
        "cbs_fm": ["cbs_fm", "CBS", "Ohnggni Radio", "/static/images/cbs.png"],
        "kbs_cool": ["kbs_cool", "KBS Cool", "Ohnggni Radio", "/static/images/kbs_cool.png"],
        "kbs_3radio": ["kbs_3radio", "KBS3", "Ohnggni Radio", "/static/images/kbs3.png"],
        "sbs_power": ["sbs_power", "SBS Power", "Ohnggni Radio", "/static/images/sbs_power.png"],
        "sbs_love": ["sbs_love", "SBS Love", "Ohnggni Radio", "/static/images/sbs_love.png"],
        "mbc_fm": ["mbc_fm", "MBC", "Ohnggni Radio", "/static/images/mbc_fm.png"],
        "mbc_fm4u": ["mbc_fm4u", "MBC FM4U", "Ohnggni Radio", "/static/images/mbc_fm4u.png"]
    };

    // ✅ 1) 파라미터 없이 실행한 경우 (모달 숨김, 로고 클릭 시 재생 유지)
    if (!channelId) {
        playModal.style.display = "none";
        return;
    }

    // ✅ 2) Play 버튼 클릭 시 채널 설정 및 재생
    playButton.addEventListener("click", function () {
        if (channelMap[channelId]) {
            console.log(`채널 선택됨: ${channelId}`);
            
            // 🎯 Play 버튼을 눌렀을 때만 채널 설정 및 재생 시작
            onChannelLogoClick(...channelMap[channelId]);

            // 🎯 모달 숨기기
            playModal.style.display = "none";

            // 🎵 오디오 재생 시도
            player.play().then(() => {
                console.log("수동 재생 성공");
            }).catch((error) => {
                console.error("수동 재생 실패:", error);
            });

        } else {
            console.warn(`잘못된 채널 ID: ${channelId}`);
            playModal.style.display = "none";
        }
    });

    // ✅ 3) 모달 표시 (파라미터가 있을 때만)
    table.style.position = "relative";
    playModal.style.display = "flex";
});
