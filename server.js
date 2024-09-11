const express = require('express');
const path = require('path');
const app = express();
const port = 3006; // 새롭게 사용하는 포트

// 정적 파일 제공을 위한 경로 설정 (frontend 폴더 사용)
app.use(express.static(path.join(__dirname, '.')));

// 기본 경로로 index.html 제공
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(port, '0.0.0.0', () => {
    console.log(`Static file server running at http://0.0.0.0:${port}`);
});
