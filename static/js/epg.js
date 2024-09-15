const EPG_URL = '/epg/xmltv.xml'; // XMLTV 파일 경로
const MATCH_LIST_URL = '/match.json'; // 매칭 JSON 파일 경로

let matchList = null; // matchList 변수를 전역으로 선언

// match.json 파일을 비동기로 로드하는 함수
async function loadMatchList() {
    try {
        const response = await fetch(MATCH_LIST_URL);
        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }
        const data = await response.json();
        matchList = data; // 전역 변수로 matchList 설정
        return data;
    } catch (error) {
        console.error('Failed to load match list:', error);
        return null;
    }
}

// EPG 데이터를 로드하는 함수 (유지)
async function loadEPGData() {
    try {
        const response = await fetch(EPG_URL);
        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }
        const data = await response.text();
        return data;
    } catch (error) {
        console.error('Failed to load EPG data:', error);
        return null;
    }
}

// 수정: 페이지 로드 시 match.json 파일을 불러오고 EPG 데이터를 로드
document.addEventListener('DOMContentLoaded', async () => {
    matchList = await loadMatchList(); // 유지: matchList 변수를 전역으로 초기화
    if (matchList && matchList.channels) { // 추가: matchList와 matchList.channels의 유효성 확인
        const epgData = await loadEPGData();
        if (epgData) {
            console.log('EPG Data:', epgData);
        }
    } else {
        console.error('Match list or channels data not available');
    }
});

// EPG 데이터를 가져와 파싱하는 함수
async function fetchEPGData() {
    try {
        const response = await fetch(EPG_URL);
        const epgText = await response.text();
        const parser = new DOMParser();
        const epgDoc = parser.parseFromString(epgText, 'text/xml');
        return epgDoc;
    } catch (error) {
        console.error('Failed to fetch EPG data:', error);
        return null;
    }
}

// XMLTV 시간 형식을 ISO 8601로 변환하는 함수
function parseXMLTVTime(xmltvTime) {
    // xmltvTime 예: "20240908140000 +0900"
    const match = xmltvTime.match(/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2}) ([+-]\d{4})/);
    if (match) {
        const [_, year, month, day, hour, minute, second, offset] = match;
        // ISO 8601 형식으로 변환 예: "2024-09-08T14:00:00+09:00"
        return `${year}-${month}-${day}T${hour}:${minute}:${second}${offset.slice(0, 3)}:${offset.slice(3)}`;
    } else {
        console.error('Invalid XMLTV time format:', xmltvTime);
        return null;
    }
}

// 현재 시간에 해당하는 EPG 프로그램을 찾아 표시하는 함수
async function displayEPGInfo(channelKey) {
    const epgData = await fetchEPGData();
    if (!epgData) return;

    const now = new Date(); // 현재 시간을 UTC 기준으로 가져옴
    console.log('Current UTC time:', now.toISOString());

    // matchList에서 채널 이름 매핑
    const matchChannel = matchList.channels.find(channel => channel.key === channelKey);
    const epgChannelName = matchChannel ? matchChannel.epg_channel_name : null;

    if (!epgChannelName) {
        document.getElementById('epg-info').textContent = 'N/A'; // 초기 상태를 'Program: N/A'로 설정
        console.log('No matching channel found in matchList for:', channelKey);
        return;
    }

    console.log('EPG Channel Name:', epgChannelName); // 로그 추가

    // EPG 프로그램 검색 로직
    const programs = epgData.querySelectorAll(`programme[channel="${epgChannelName}"]`);
    let currentProgram = null;

    programs.forEach(program => {
        const start = parseXMLTVTime(program.getAttribute('start'));
        const end = parseXMLTVTime(program.getAttribute('stop'));

        if (start && end) {
            const startDate = new Date(start);
            const endDate = new Date(end);

            if (startDate <= now && now < endDate) {
                currentProgram = program;
            }
        }
    });

    if (currentProgram) {
        const title = currentProgram.querySelector('title') ? currentProgram.querySelector('title').textContent : 'No title available';
        document.getElementById('epg-info').textContent = ` ${title}`; // 수정: title을 표시

        // 추가: currentArtist 업데이트
        currentArtist = title; // 현재 프로그램 제목으로 artist 설정

        // Media Session 메타데이터 업데이트
        setMediaSessionData(currentChannelTitle, currentArtist, currentImage); // script.js에서 정의된 함수 호출
    } else {
        document.getElementById('epg-info').textContent = ' No information';
        console.log('No program found for current time on channel:', epgChannelName);
    }
}

function scheduleEPGUpdates() {
    const now = new Date();
    const minutes = now.getMinutes();
    const nextUpdateInMilliseconds = ((5 - (minutes % 5)) * 60 * 1000) - (now.getSeconds() * 1000 + now.getMilliseconds());
    
    // 현재 시각을 기준으로 5분이 되는 시각까지 대기
    setTimeout(() => {
        updateEPGAndMetadata(); // 첫 업데이트 비동기 호출
        setInterval(async () => {
            await updateEPGAndMetadata(); // 5분마다 비동기 업데이트
        }, 5 * 60 * 1000);
    }, nextUpdateInMilliseconds);
}

// 페이지 로드 시 EPG 업데이트 스케줄러 호출
document.addEventListener('DOMContentLoaded', async () => {
    matchList = await loadMatchList();
    if (matchList && matchList.channels) {
        const epgData = await loadEPGData();
        if (epgData) {
            console.log('EPG Data:', epgData);
            scheduleEPGUpdates(); // EPG 정보 업데이트 스케줄러 시작
        }
    } else {
        console.error('Match list or channels data not available');
    }
});

// EPG 정보와 메타데이터를 비동기적으로 업데이트하는 함수
async function updateEPGAndMetadata() {
    try {
        await displayEPGInfo(currentChannelKey); // EPG 정보 업데이트

        // 메타데이터 업데이트
        if (currentChannelTitle && currentArtist && currentImage) {
            setMediaSessionData(currentChannelTitle, currentArtist, currentImage);
        }

        // 오디오 재생 상태 확인 후 재생 중이 아니면 재시작 (불필요하므로 주석처리)
        //if (audioElement.paused) {
        //    audioElement.play().catch(error => console.error('오디오 재생 중 오류 발생:', error));
        //}
    } catch (error) {
        console.error('EPG 업데이트 중 오류 발생:', error);
    }
}
