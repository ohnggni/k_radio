const express = require('express');
const path = require('path');
const app = express();
const port = process.env.FRONTEND_PORT; // 새롭게 사용하는 포트
const serverIp = process.env.SERVER_IP || 'localhost'; // 도커환경 변수에서 server ip 가져옴

// 정적 파일 제공을 위한 경로 설정
app.use('/static', express.static(path.join(__dirname, 'static')));
app.use('/epg', express.static(path.join(__dirname, 'epg'))); // EPG 경로 설정
app.use(express.static(__dirname)); // 기본 경로 설정

// 기본 경로로 index.html 제공
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// 서버 IP를 클라이언트에 전달하기 위해 변수 삽입
app.get('/config.js', (req, res) => {
    res.type('.js');
    res.send(`const SERVER_IP = '${serverIp}';`);
});

app.listen(port, '0.0.0.0', () => {
    console.log(`Static file server running at http://0.0.0.0:${port}`);
});
