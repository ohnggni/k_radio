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
        changeAudioSource(`https://${SERVER_IP}/radio?keys=${currentChannelKey}&token=homeassistant&atype=${currentQuality}`, currentChannelKey, currentChannelTitle, currentArtist, currentImage);
    }
});


// 유지 및 수정: 채널 로고를 클릭할 때 호출되는 함수
function onChannelLogoClick(key, title, artist, image) {
    currentChannelKey = key;  // 클릭된 채널의 key 값으로 설정
    currentChannelTitle = title; // 클릭된 채널의 title 값으로 설정
    currentArtist = artist; // 클릭된 채널의 artist 값으로 설정
    currentImage = image; // 클릭된 채널의 이미지 값으로 설정
    changeAudioSource(`https://${SERVER_IP}/radio?keys=${key}&token=homeassistant&atype=${currentQuality}`, key, title, artist, image); // SERVER_IP는 server.js(도커환경변수에서부터)에서 사전에 지정
    
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
    playingStatusElement.textContent = "paused"; // Pause 기호로 업데이트
    playingStatusElement.style.display = 'inline'; // 상태 텍스트 보이기
});

// 오디오 재생이 시작되었을 때 상태 업데이트
audioElement.addEventListener('play', function () {
    playingStatusElement.textContent = "playing"; // Play 기호로 업데이트
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

// airplay button 처리
document.addEventListener('DOMContentLoaded', () => {
    const player = document.querySelector("#globalAudioPlayer")
    const button = document.querySelector("#airplay-button")
    let isAirPlayAvailable = false

    player.addEventListener("webkitplaybacktargetavailabilitychanged", event => {
        if (event.availability === "available") {
            isAirPlayAvailable = true
        }
    })

    button.addEventListener("click", () => {
        if (isAirPlayAvailable) {
            player.webkitShowPlaybackTargetPicker()
        }
    })
});
