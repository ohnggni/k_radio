// script.js의 기존 로직(오디오 소스 전환, EPG, 모달)은 건드리지 않고,
// 같은 #globalAudioPlayer 엘리먼트에 커스텀 UI만 얹는다.

document.addEventListener('DOMContentLoaded', function () {
    const audio = document.getElementById('globalAudioPlayer');
    const playPauseButton = document.getElementById('playPauseButton');
    const iconPlay = document.getElementById('iconPlay');
    const iconPause = document.getElementById('iconPause');
    const muteButton = document.getElementById('muteButton');
    const volumeIconOn = document.getElementById('volumeIconOn');
    const volumeIconOff = document.getElementById('volumeIconOff');
    const volumeSlider = document.getElementById('volumeSlider');
    const playerBar = document.querySelector('.player-bar');
    const channelGrid = document.querySelector('.channel-grid');

    // 재생/일시정지 토글
    playPauseButton.addEventListener('click', function () {
        if (!audio.src) return; // 아직 채널 선택 전
        if (audio.paused) {
            audio.play().catch(() => {});
        } else {
            audio.pause();
        }
    });

    function syncPlayIcon() {
        const playing = !audio.paused;
        iconPlay.style.display = playing ? 'none' : 'block';
        iconPause.style.display = playing ? 'block' : 'none';
        playerBar.classList.toggle('is-playing', playing);
    }

    audio.addEventListener('play', syncPlayIcon);
    audio.addEventListener('pause', syncPlayIcon);
    audio.addEventListener('emptied', syncPlayIcon);

    // 볼륨 슬라이더
    volumeSlider.addEventListener('input', function () {
        audio.volume = parseFloat(volumeSlider.value);
        audio.muted = false;
        syncVolumeIcon();
    });

    function syncVolumeIcon() {
        const silent = audio.muted || audio.volume === 0;
        volumeIconOn.style.display = silent ? 'none' : 'block';
        volumeIconOff.style.display = silent ? 'block' : 'none';
    }

    muteButton.addEventListener('click', function () {
        audio.muted = !audio.muted;
        syncVolumeIcon();
    });

    // 채널 카드 선택 표시 (실제 재생 로직은 index.html의 onclick이 처리)
    if (channelGrid) {
        channelGrid.addEventListener('click', function (event) {
            const card = event.target.closest('.channel-card');
            if (!card) return;
            channelGrid.querySelectorAll('.channel-card.is-active').forEach(function (el) {
                el.classList.remove('is-active');
            });
            card.classList.add('is-active');
        });
    }

    syncPlayIcon();
    syncVolumeIcon();
});
