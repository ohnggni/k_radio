// channels.json을 읽어 채널 그리드 버튼을 동적으로 생성하고,
// script.js가 참조할 window.CHANNEL_MAP도 여기서 함께 채운다.
// 새 방송을 추가하려면 이 파일이 아니라 /static/channels.json만 수정하면 된다.

document.addEventListener('DOMContentLoaded', function () {
    const grid = document.querySelector('.channel-grid');
    if (!grid) return;

    fetch('/static/channels.json')
        .then(function (res) { return res.json(); })
        .then(function (channels) {
            window.CHANNEL_MAP = {};

            channels.forEach(function (ch) {
                // script.js의 onChannelLogoClick / channelMap 형식과 동일하게 [key, title, artist, logo]
                window.CHANNEL_MAP[ch.key] = [ch.key, ch.title, ch.artist, ch.logo];

                const btn = document.createElement('button');
                btn.type = 'button';
                btn.className = 'channel-card';
                btn.addEventListener('click', function () {
                    onChannelLogoClick(ch.key, ch.title, ch.artist, ch.logo);
                });

                const img = document.createElement('img');
                img.src = ch.logo;
                img.alt = ch.alt || ch.title;
                btn.appendChild(img);

                grid.appendChild(btn);
            });
        })
        .catch(function (err) {
            console.error('채널 목록을 불러오지 못했습니다:', err);
        });
});
