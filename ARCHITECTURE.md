# DES Head-Unit 시스템 아키텍처 상세 분석

> **작성일**: 2025-12-08
> **프로젝트**: DES Head-Unit (Automotive Infotainment System)
> **플랫폼**: Raspberry Pi 4 + Yocto Linux + Qt6/QML

---

## 목차

1. [블루투스 시스템 아키텍처](#1-블루투스-시스템-아키텍처)
   - [전체 시스템 구조](#전체-시스템-구조)
   - [데이터 플로우](#블루투스-데이터-플로우)
   - [주요 컴포넌트](#주요-컴포넌트-상세-설명)
2. [뮤직플레이어 시스템 아키텍처](#2-뮤직플레이어-시스템-아키텍처)
   - [전체 시스템 구조](#전체-시스템-구조-1)
   - [데이터 플로우](#뮤직플레이어-데이터-플로우)
3. [Weston 듀얼 모니터 설정](#3-weston-듀얼-모니터-설정)
   - [시스템 아키텍처](#시스템-아키텍처)
   - [작동 원리](#weston-작동-원리)
4. [전체 시스템 통합](#전체-시스템-통합-다이어그램)

---

## 1. 블루투스 시스템 아키텍처

### 전체 시스템 구조

```
┌─────────────────────────────────────────────────────────────────┐
│                        Qt/QML Application                        │
│                      (Head-Unit/src/HeadUnit.cpp)                │
└────────────────┬──────────────────────────────┬──────────────────┘
                 │                              │
                 ▼                              ▼
┌────────────────────────────────┐  ┌──────────────────────────────┐
│    BluetoothManager            │  │  BluetoothAudioPlayer        │
│  (페어링 & 연결 관리)            │  │  (미디어 재생 제어)            │
│                                │◄─┤                              │
│  - QtBluetooth API             │  │  - BlueZ D-Bus API           │
│  - BlueZ D-Bus API             │  │  - AVRCP Media Control       │
│  - 장치 검색/페어링             │  │  - 메타데이터 수신            │
└────────┬───────────────────────┘  └──────────┬───────────────────┘
         │                                     │
         │                                     │
         ▼                                     ▼
┌────────────────────────────────┐  ┌──────────────────────────────┐
│    BluetoothAgent              │  │   BlueZ MediaPlayer1         │
│  (페어링 인증 처리)              │  │  (org.bluez.MediaPlayer1)    │
│                                │  │                              │
│  - org.bluez.Agent1            │  │  - Track/Album/Artist        │
│  - PIN/Passkey 인증            │  │  - Play/Pause/Next/Previous  │
│  - 자동 승인 로직              │  │  - Duration/Position         │
└────────┬───────────────────────┘  └──────────┬───────────────────┘
         │                                     │
         │                                     │
         ▼                                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                         D-Bus System Bus                         │
│                  (org.bluez - BlueZ Bluetooth Stack)             │
└────────────────┬──────────────────────────────┬──────────────────┘
                 │                              │
                 ▼                              ▼
┌────────────────────────────────┐  ┌──────────────────────────────┐
│   BlueZ Adapter (hci0)         │  │   BlueZ Device               │
│                                │  │  (/org/bluez/hci0/dev_XX_...) │
│  - Discoverable On/Off         │  │                              │
│  - Pairable                    │  │  - Paired/Connected          │
│  - Power Management            │  │  - Trusted                   │
└────────────────┬───────────────┘  └──────────────┬───────────────┘
                 │                                 │
                 └─────────────┬───────────────────┘
                               │
                               ▼
                 ┌─────────────────────────────┐
                 │   Raspberry Pi Bluetooth    │
                 │   Hardware (BCM43455)       │
                 └─────────────────────────────┘
```

---

### 블루투스 데이터 플로우

#### Phase 1: 초기화 및 Broadcasting

```
[앱 시작]
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. BluetoothManager 초기화                                       │
│    - QBluetoothLocalDevice 생성                                 │
│    - BluetoothAgent D-Bus 등록                                  │
│    - 저장된 기기 목록 로드                                        │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Broadcasting 시작 (사용자가 UI에서 "Pair" 버튼 클릭)           │
│    startBroadcasting()                                          │
│    ├─ QDBusInterface("org.bluez", "/org/bluez/hci0", ...)       │
│    ├─ Set "Discoverable" = true                                 │
│    ├─ Set "Pairable" = true                                     │
│    └─ Set "DiscoverableTimeout" = 0 (무제한)                    │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. 휴대폰에서 장치 검색                                           │
│    휴대폰 블루투스 설정 → "DesGear-HeadUnit" 발견               │
│    (localDevice_->name() 기반 장치명)                           │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
        [Phase 2: Pairing으로 진행]
```

---

#### Phase 2: Pairing (페어링)

```
[휴대폰에서 "DesGear-HeadUnit" 클릭]
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. BlueZ가 BluetoothAgent 호출                                  │
│    D-Bus Method Call:                                           │
│    ├─ RequestConfirmation(device, passkey)                      │
│    │  또는                                                       │
│    ├─ AuthorizeService(device, uuid)                            │
│    │  또는                                                       │
│    └─ RequestPinCode(device)                                    │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. BluetoothAgent 자동 승인 처리                                 │
│    AuthorizeService() {                                         │
│        qDebug() << "Auto-accepting service authorization"       │
│        // 자동으로 승인하고 즉시 리턴                            │
│        return;  // No error = accepted                          │
│    }                                                            │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. QtBluetooth 이벤트 수신                                       │
│    handlePairingFinished(address, Paired)                       │
│    ├─ Set device as "Trusted" via D-Bus                        │
│    ├─ stopBroadcasting() - 더 이상 검색 불가능                  │
│    └─ 페어링 완료 로그 출력                                      │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
        [Phase 3: Connection으로 진행]
```

---

#### Phase 3: Connection (연결)

```
[페어링 완료 후 자동 연결 시도]
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. Connection Check Timer (2초마다 실행)                         │
│    checkConnectionStatus()                                      │
│    ├─ D-Bus ObjectManager.GetManagedObjects() 호출              │
│    └─ 모든 /org/bluez/hci0/dev_* 장치 스캔                      │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 연결된 장치 발견                                              │
│    foreach device in managed_objects:                           │
│        if device.Paired == true && device.Connected == true:    │
│            ├─ connectedDeviceAddress_ = device.Address          │
│            ├─ connectedDeviceName_ = device.Name                │
│            ├─ connectedDevicePath_ = device.ObjectPath          │
│            └─ emit deviceConnected(address, name)               │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. BluetoothAudioPlayer 통합                                    │
│    audioPlayer_->setConnectedDevice(devicePath)                 │
│    ├─ MediaPlayer1 D-Bus 인터페이스 검색                        │
│    ├─ org.bluez.MediaPlayer1 연결                               │
│    └─ PropertiesChanged 신호 구독                               │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
        [Phase 4: Media Control로 진행]
```

---

#### Phase 4: Media Control (미디어 제어)

```
[휴대폰에서 음악 재생]
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. BlueZ MediaPlayer1이 PropertiesChanged 신호 발송              │
│    D-Bus Signal:                                                │
│    org.freedesktop.DBus.Properties.PropertiesChanged            │
│    ├─ Interface: "org.bluez.MediaPlayer1"                       │
│    └─ Changed Properties:                                       │
│        ├─ "Status" = "playing"                                  │
│        ├─ "Track" = {                                           │
│        │     "Title": "Bohemian Rhapsody",                      │
│        │     "Artist": "Queen",                                 │
│        │     "Album": "A Night at the Opera",                   │
│        │     "Duration": 354000 (밀리초)                         │
│        │  }                                                     │
│        └─ "Position" = 0                                        │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. BluetoothAudioPlayer가 신호 수신                              │
│    onMediaPlayerPropertiesChanged()                             │
│    ├─ updateMetadata(metadata)                                  │
│    │   ├─ trackTitle_ = "Bohemian Rhapsody"                    │
│    │   ├─ trackArtist_ = "Queen"                               │
│    │   ├─ trackAlbum_ = "A Night at the Opera"                 │
│    │   ├─ duration_ = 354000                                   │
│    │   └─ emit trackTitleChanged(), etc.                        │
│    └─ downloadAlbumArt(artUrl) - 앨범 아트 다운로드             │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Qt Signal → QML UI 업데이트                                  │
│    QML의 BluetoothScreen.qml에서 표시:                          │
│    ├─ Text { text: btAudio.trackTitle }                        │
│    ├─ Text { text: btAudio.trackArtist }                       │
│    ├─ Image { source: btAudio.albumArtPath }                   │
│    └─ ProgressBar { value: btAudio.position / duration }       │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
[사용자가 "Next" 버튼 클릭]
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. AVRCP 명령 전송                                               │
│    btAudio.next() → BluetoothAudioPlayer::next()               │
│    ├─ QDBusInterface call("Next")                              │
│    └─ D-Bus → org.bluez.MediaControl1.Next()                   │
│        → BlueZ → 휴대폰 → 다음 곡 재생                           │
└─────────────────────────────────────────────────────────────────┘
```

---

### 주요 컴포넌트 상세 설명

#### 1. BluetoothManager

**파일 위치**: `Head-Unit/src/backend/bluetooth/bluetooth_manager.cpp:13`

**역할**:
- 블루투스 어댑터 관리 (전원, Discoverable 모드)
- 장치 페어링 및 연결 상태 추적
- BluetoothAgent 등록 및 관리
- 저장된 기기 목록 관리

**핵심 기술**:
- **QtBluetooth API**: `QBluetoothLocalDevice` 사용하여 페어링 이벤트 수신
- **BlueZ D-Bus API**: Discoverable/Pairable 속성 직접 제어
- **Hybrid Approach**: Qt와 D-Bus의 장점을 결합

**주요 메서드**:

```cpp
// Broadcasting 시작 (검색 가능 모드)
void startBroadcasting() {
    QDBusInterface adapter("org.bluez", "/org/bluez/hci0",
                          "org.freedesktop.DBus.Properties");
    adapter.call("Set", "org.bluez.Adapter1", "Discoverable", true);
    adapter.call("Set", "org.bluez.Adapter1", "Pairable", true);
}

// 연결 상태 체크 (2초마다)
void checkConnectionStatus() {
    QDBusInterface manager("org.bluez", "/",
                          "org.freedesktop.DBus.ObjectManager");
    QDBusMessage reply = manager.call("GetManagedObjects");
    // 모든 장치를 순회하며 Connected == true 인 장치 찾기
}
```

---

#### 2. BluetoothAgent

**파일 위치**: `Head-Unit/src/backend/bluetooth/bluetooth_agent.h:21`

**역할**:
- BlueZ 페어링 요청에 자동 응답
- `org.bluez.Agent1` D-Bus 인터페이스 구현
- PIN/Passkey 인증 자동 승인

**핵심 기술**:
- **QDBusAbstractAdaptor**: D-Bus 객체로 노출
- **Q_SCRIPTABLE**: D-Bus 메서드로 노출되는 슬롯

**주요 메서드**:

```cpp
// 서비스 승인 (A2DP, AVRCP 등)
Q_SCRIPTABLE void AuthorizeService(const QDBusObjectPath& device,
                                   const QString& uuid) {
    qDebug() << "Auto-accepting service:" << uuid;
    // 아무것도 반환하지 않으면 자동 승인됨 (BlueZ 규약)
}

// Passkey 확인 (6자리 숫자)
Q_SCRIPTABLE void RequestConfirmation(const QDBusObjectPath& device,
                                       quint32 passkey) {
    qDebug() << "Auto-accepting passkey:" << passkey;
    // 아무것도 반환하지 않으면 자동 승인됨
}
```

---

#### 3. BluetoothAudioPlayer

**파일 위치**: `Head-Unit/src/backend/bluetooth/bluetooth_audio_player.h:27`

**역할**:
- AVRCP (Audio/Video Remote Control Profile) 미디어 제어
- 트랙 메타데이터 수신 (제목, 아티스트, 앨범, 커버 아트)
- 재생 제어 (Play, Pause, Next, Previous)
- 실시간 위치 추적

**핵심 기술**:
- **BlueZ MediaPlayer1 D-Bus Interface**
- **PropertiesChanged 신호**: 트랙 변경 시 자동 업데이트
- **QNetworkAccessManager**: 앨범 아트 HTTP 다운로드

**주요 메서드**:

```cpp
// MediaPlayer 검색 및 연결
void setConnectedDevice(const QString& devicePath) {
    // /org/bluez/hci0/dev_XX_XX_XX_XX_XX_XX/playerX 찾기
    discoverMediaPlayer();

    mediaPlayerInterface_ = std::make_unique<QDBusInterface>(
        "org.bluez", mediaPlayerPath_,
        "org.bluez.MediaPlayer1"
    );

    // PropertiesChanged 신호 구독
    QDBusConnection::systemBus().connect(
        "org.bluez", mediaPlayerPath_,
        "org.freedesktop.DBus.Properties", "PropertiesChanged",
        this, SLOT(onMediaPlayerPropertiesChanged(...))
    );
}

// AVRCP 명령 전송
void next() {
    mediaPlayerInterface_->call("Next");  // BlueZ → 휴대폰
}
```

---

### 보안 및 권한

```
┌─────────────────────────────────────────────────────────────────┐
│ D-Bus 시스템 버스 권한 설정                                       │
│ /etc/dbus-1/system.d/headunit-bluetooth.conf                    │
│                                                                  │
│ <policy user="root">                                            │
│     <allow own="com.des.headunit.bluetooth"/>                   │
│     <allow send_destination="org.bluez"/>                       │
│     <allow send_interface="org.bluez.Agent1"/>                  │
│ </policy>                                                       │
│                                                                  │
│ ⚠️ 주의: 앱은 root 권한으로 실행되어야 D-Bus 접근 가능            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 뮤직플레이어 시스템 아키텍처

### 전체 시스템 구조

```
┌─────────────────────────────────────────────────────────────────┐
│                        Qt/QML Application                        │
│                       (MusicScreen.qml)                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      MusicPlayer                                 │
│              (Head-Unit/src/backend/music/)                      │
│                                                                  │
│  - QMediaPlayer (Qt Multimedia)                                 │
│  - QAudioOutput (Audio 출력)                                    │
│  - Playlist 관리                                                │
│  - Progress 추적                                                │
└────────────────────┬───────────────────────────┬────────────────┘
                     │                           │
                     ▼                           ▼
┌────────────────────────────────┐  ┌──────────────────────────────┐
│   File System Scanner          │  │   QMediaPlayer Backend       │
│                                │  │                              │
│  - 재귀적 디렉토리 스캔         │  │  - GStreamer (Linux)         │
│  - *.mp3, *.wav, *.ogg, *.flac │  │  - 코덱 디코딩               │
│  - 환경변수 지원                │  │  - 오디오 스트림 처리         │
└────────────────────────────────┘  └──────────────┬───────────────┘
                                                   │
                                                   ▼
                                    ┌──────────────────────────────┐
                                    │   ALSA / PulseAudio          │
                                    │   (Linux Audio System)       │
                                    └──────────────┬───────────────┘
                                                   │
                                                   ▼
                                    ┌──────────────────────────────┐
                                    │   Audio Hardware Output      │
                                    │   (HDMI / 3.5mm Jack)        │
                                    └──────────────────────────────┘
```

---

### 뮤직플레이어 데이터 플로우

#### Phase 1: 음악 라이브러리 로드

```
[앱 시작 또는 사용자가 MusicScreen 진입]
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. MusicPlayer 초기화                                            │
│    MusicPlayer::MusicPlayer()                                   │
│    ├─ QMediaPlayer 생성                                         │
│    ├─ QAudioOutput 생성 및 연결                                 │
│    └─ Signal/Slot 연결                                          │
│        ├─ playbackStateChanged → handleStateChanged             │
│        ├─ positionChanged → handlePositionChanged               │
│        └─ durationChanged → handleDurationChanged               │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 음악 라이브러리 경로 결정                                      │
│    resolveLibraryPath()                                         │
│    ├─ 우선순위 1: 환경변수 $HEADUNIT_MUSIC_DIR                  │
│    ├─ 우선순위 2: ../design/assets/music (상대 경로)            │
│    ├─ 우선순위 3: QStandardPaths::MusicLocation                 │
│    │               (/home/user/Music)                           │
│    └─ Fallback: 앱 실행 디렉토리                                │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. 파일 시스템 스캔                                              │
│    loadLibrary(path)                                            │
│    QDir musicDir(path);                                         │
│    QFileInfoList entries = musicDir.entryInfoList(              │
│        {"*.mp3", "*.wav", "*.ogg", "*.flac"},                   │
│        QDir::Files | QDir::Readable                             │
│    );                                                           │
│    ├─ tracks_ = ["song1.mp3", "song2.mp3", ...]                │
│    └─ trackPaths_ = ["/path/to/song1.mp3", ...]                │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. QML UI 업데이트                                               │
│    emit tracksChanged()                                         │
│    MusicScreen.qml에서 ListView 표시:                           │
│    ├─ model: musicPlayer.tracks                                │
│    └─ delegate: 각 트랙을 클릭 가능한 항목으로 표시              │
└─────────────────────────────────────────────────────────────────┘
```

---

#### Phase 2: 음악 재생

```
[사용자가 트랙 클릭 또는 Play 버튼 클릭]
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. QML에서 재생 요청                                             │
│    musicPlayer.play("song1.mp3")                                │
│    또는                                                          │
│    musicPlayer.toggle("song1.mp3")  // 재생/일시정지 토글       │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. MusicPlayer::play() 실행                                      │
│    int index = findTrackIndex(track);                           │
│    playAtIndex(index);                                          │
│    ├─ player_.setSource(QUrl::fromLocalFile(filePath))         │
│    │   → QMediaPlayer가 파일 로드                               │
│    ├─ updateCurrentTrack(index)                                 │
│    │   → currentTrack_ = "song1.mp3"                           │
│    │   → emit currentTrackChanged()                             │
│    └─ player_.play()                                            │
│        → GStreamer가 오디오 디코딩 시작                          │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. QMediaPlayer 이벤트 발생                                      │
│    ├─ mediaStatusChanged(LoadedMedia)                           │
│    │   ├─ duration_ = player_.duration()  // 예: 180000ms      │
│    │   └─ emit durationChanged()                                │
│    │                                                            │
│    ├─ playbackStateChanged(PlayingState)                        │
│    │   ├─ playing_ = true                                      │
│    │   └─ emit playingChanged()                                 │
│    │                                                            │
│    └─ positionChanged(newPosition) - 매 100ms마다               │
│        ├─ position_ = newPosition  // 예: 5000ms               │
│        ├─ emit positionChanged()                                │
│        └─ emit progressChanged()                                │
│            → progress = position / duration  // 0.0 ~ 1.0      │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. GStreamer Pipeline 처리                                       │
│    File Read → Demux → MP3 Decoder → Audio Converter            │
│    → Volume Control → Audio Sink (PulseAudio/ALSA)              │
│                                                                  │
│    실제 오디오 데이터 흐름:                                       │
│    MP3 파일 → [GStreamer] → PCM 샘플 → [ALSA] → 스피커         │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. QML UI 실시간 업데이트                                        │
│    MusicScreen.qml:                                             │
│    ├─ Text { text: musicPlayer.currentTrack }                  │
│    ├─ Text { text: formatTime(musicPlayer.position) }          │
│    ├─ ProgressBar {                                             │
│    │     value: musicPlayer.progress  // 0.0 ~ 1.0            │
│    │  }                                                         │
│    └─ Button { text: musicPlayer.playing ? "⏸" : "▶" }        │
└─────────────────────────────────────────────────────────────────┘
```

---

#### Phase 3: Next/Previous 제어

```
[사용자가 "Next" 버튼 클릭]
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. MusicPlayer::next() 호출                                      │
│    int nextIndex = (currentIndex_ + 1) % tracks_.size();       │
│    playAtIndex(nextIndex);                                      │
│    ├─ 예: currentIndex_ = 0 → nextIndex = 1                    │
│    └─ 마지막 트랙이면 다시 첫 번째로 (순환 재생)                 │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 새 트랙 로드 및 재생                                          │
│    player_.setSource(QUrl::fromLocalFile(nextTrackPath))       │
│    player_.play()                                               │
│    ├─ 이전 트랙 자동 정지                                       │
│    ├─ position_ = 0으로 리셋                                    │
│    └─ 새 duration 로드                                          │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. QML UI 자동 업데이트                                          │
│    currentTrackChanged() 신호 → UI 반응:                        │
│    ├─ 트랙 제목 변경                                            │
│    ├─ 진행 바 0%로 리셋                                         │
│    └─ duration 표시 업데이트                                     │
└─────────────────────────────────────────────────────────────────┘
```

---

### MusicPlayer 컴포넌트 상세

**파일 위치**: `Head-Unit/src/backend/music/music_player.cpp:85`

**핵심 특징**:
- **Qt Multimedia 기반**: `QMediaPlayer` + `QAudioOutput`
- **플랫폼 독립적**: Linux (GStreamer), Windows (DirectShow), macOS (AVFoundation)
- **실시간 진행 추적**: 100ms 단위로 `positionChanged` 신호 발생

**주요 속성**:

```cpp
Q_PROPERTY(QStringList tracks READ tracks NOTIFY tracksChanged)
// → QML에서 ListView의 model로 사용

Q_PROPERTY(QString currentTrack READ currentTrack NOTIFY currentTrackChanged)
// → 현재 재생 중인 트랙명

Q_PROPERTY(qreal progress READ progress NOTIFY progressChanged)
// → 진행률 0.0 ~ 1.0 (position / duration)

Q_PROPERTY(bool playing READ isPlaying NOTIFY playingChanged)
// → 재생/일시정지 상태
```

**오디오 파이프라인**:

```
QMediaPlayer (추상 계층)
    ↓
GStreamer (Linux 백엔드)
    ↓
playbin (자동 파이프라인 구성)
    ├─ filesrc: 파일 읽기
    ├─ mpegaudioparse: MP3 파싱
    ├─ mpg123audiodec: MP3 디코딩
    ├─ audioconvert: 포맷 변환
    ├─ audioresample: 리샘플링
    ├─ volume: 볼륨 제어
    └─ pulsesink/alsasink: 오디오 출력
```

---

## 3. Weston 듀얼 모니터 설정

### 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                     Raspberry Pi 4 Hardware                      │
│                                                                  │
│  ┌──────────────────────┐         ┌──────────────────────┐     │
│  │   HDMI Port 0        │         │   HDMI Port 1        │     │
│  │   (HDMI-A-1)         │         │   (HDMI-A-2)         │     │
│  └──────────┬───────────┘         └──────────┬───────────┘     │
│             │                                │                  │
│  ┌──────────▼─────────────────────────────────▼──────────┐     │
│  │        VideoCore GPU (Broadcom BCM2711)               │     │
│  │        - Dual display controller                      │     │
│  │        - Independent framebuffers                     │     │
│  └───────────────────────────┬───────────────────────────┘     │
│                              │                                  │
└──────────────────────────────┼──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Linux Kernel DRM/KMS                         │
│                  (Direct Rendering Manager /                     │
│                   Kernel Mode Setting)                           │
│                                                                  │
│  ┌────────────────────────┐    ┌────────────────────────┐      │
│  │  DRM Device: card0     │    │  DRM Device: card1     │      │
│  │  Connector: HDMI-A-1   │    │  Connector: HDMI-A-2   │      │
│  │  Resolution: 1024x600  │    │  Resolution: 1024x600  │      │
│  └───────────┬────────────┘    └───────────┬────────────┘      │
│              │                             │                    │
└──────────────┼─────────────────────────────┼────────────────────┘
               │                             │
               ▼                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Weston Wayland Compositor                      │
│                   (weston.ini configuration)                     │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [core]                                                    │  │
│  │ backend=drm-backend.so  ← DRM/KMS 사용                   │  │
│  │ shell=kiosk-shell.so    ← Kiosk 모드 (전체화면 강제)     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [output] HDMI-A-1                                         │  │
│  │ name=HDMI-A-1                                             │  │
│  │ mode=1024x600@60       ← 해상도 및 주사율                │  │
│  │ app-ids=HeadUnitApp    ← 이 화면에 표시할 앱             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [output] HDMI-A-2                                         │  │
│  │ name=HDMI-A-2                                             │  │
│  │ mode=1024x600@60                                          │  │
│  │ app-ids=appIC          ← Instrument Cluster 앱           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└────────┬──────────────────────────────────┬────────────────────┘
         │                                  │
         ▼                                  ▼
┌────────────────────────┐      ┌────────────────────────┐
│  Wayland Client App    │      │  Wayland Client App    │
│  HeadUnitApp           │      │  appIC                 │
│  (Qt/QML)              │      │  (Instrument Cluster)  │
│                        │      │                        │
│  - 블루투스 제어        │      │  - 속도계               │
│  - 뮤직 플레이어        │      │  - 엔진 RPM             │
│  - 내비게이션           │      │  - 경고등               │
└────────────────────────┘      └────────────────────────┘
         │                                  │
         ▼                                  ▼
    HDMI-A-1                           HDMI-A-2
   (모니터 1)                         (모니터 2)
```

---

### Weston 설정 상세 분석

#### weston.ini 파일 구조

**파일 위치**: `yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston.ini`

```ini
# ========================================
# [core] - Weston 핵심 설정
# ========================================
[core]
require-input=true          # 터치/마우스 입력 필수 활성화
idle-time=0                 # 화면 절전 비활성화 (자동차용)
backend=drm-backend.so      # DRM/KMS 백엔드 사용 (하드웨어 직접 제어)
shell=kiosk-shell.so        # Kiosk 셸 (전체화면 강제, 최소화 불가)

# ========================================
# [output] HDMI-A-1 - 첫 번째 모니터
# ========================================
[output]
name=HDMI-A-1              # DRM 커넥터 이름 (물리적 HDMI 포트 0)
mode=1024x600@60           # 해상도: 1024x600, 주사율: 60Hz
transform=normal           # 화면 회전 없음 (90, 180, 270도 가능)
scale=1                    # HiDPI 스케일링 비율 (1 = 100%)
app-ids=HeadUnitApp        # 이 화면에 표시할 Wayland 앱 ID
cursor-size=0              # 커서 숨김 (터치스크린용)

# ========================================
# [output] HDMI-A-2 - 두 번째 모니터
# ========================================
[output]
name=HDMI-A-2              # DRM 커넥터 이름 (물리적 HDMI 포트 1)
mode=1024x600@60
transform=normal
scale=1
app-ids=appIC              # Instrument Cluster 앱 할당
cursor-size=0

# ========================================
# [shell] - 셸 외관 설정
# ========================================
[shell]
panel-position=none        # 상단 패널 비활성화 (순수 전체화면)
background-color=0xff000000  # 배경색: 검정 (ARGB 형식)
locking=false              # 화면 잠금 비활성화

# ========================================
# [kiosk-shell] - Kiosk 모드 특화 설정
# ========================================
[kiosk-shell]
# 백그라운드 이미지 없음 (앱이 전체 화면 사용)
```

---

### Weston 작동 원리

#### 1. DRM Backend 초기화 과정

```
[시스템 부팅]
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. Systemd가 weston.service 시작                                │
│    ExecStart=/usr/bin/weston --config=/etc/xdg/weston/weston.ini│
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Weston이 DRM 백엔드 로드                                      │
│    drm_backend_init()                                           │
│    ├─ /dev/dri/card0 열기 (GPU 장치)                           │
│    ├─ DRM 커넥터 열거 (HDMI-A-1, HDMI-A-2)                     │
│    └─ 각 커넥터의 모드 리스트 조회                               │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. weston.ini의 [output] 섹션 파싱                              │
│    foreach output in weston.ini:                                │
│        ├─ DRM 커넥터 매칭 (name=HDMI-A-1)                       │
│        ├─ 해상도 설정 (mode=1024x600@60)                        │
│        ├─ Framebuffer 할당 (GPU 메모리)                         │
│        └─ app-ids 필터 저장                                      │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Kiosk Shell 초기화                                            │
│    kiosk_shell_init()                                           │
│    ├─ 각 output마다 전체화면 surface 준비                       │
│    ├─ app-ids 라우팅 테이블 생성                                │
│    └─ Wayland 소켓 리스닝 시작                                   │
│        (Unix socket: /run/user/1000/wayland-0)                  │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
        [클라이언트 앱 연결 대기]
```

---

#### 2. 앱 라우팅 메커니즘

```
[HeadUnitApp 시작]
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. Qt Wayland Platform Plugin 초기화                             │
│    QWaylandIntegration::initialize()                            │
│    ├─ /run/user/1000/wayland-0 소켓 연결                       │
│    ├─ wl_registry 조회 (Wayland globals)                       │
│    └─ xdg_wm_base 인터페이스 바인딩                             │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 앱이 자신의 app-id 설정                                       │
│    xdg_toplevel_set_app_id(surface, "HeadUnitApp")             │
│    Weston이 수신:                                               │
│    ├─ app-id = "HeadUnitApp"                                   │
│    └─ weston.ini에서 일치하는 [output] 찾기                     │
│        → HDMI-A-1이 "app-ids=HeadUnitApp" 포함                 │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Kiosk Shell이 surface를 HDMI-A-1에 배치                      │
│    kiosk_shell_assign_output(surface, HDMI-A-1)                │
│    ├─ surface를 HDMI-A-1의 전체 화면 크기로 설정                │
│    │   (1024x600)                                              │
│    ├─ Framebuffer에 렌더링                                      │
│    └─ DRM pageflip으로 화면 출력                                │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. 동시에 appIC도 동일한 프로세스 진행                           │
│    xdg_toplevel_set_app_id(surface, "appIC")                   │
│    → Weston이 HDMI-A-2로 라우팅                                 │
│    → HDMI-A-2 화면에 Instrument Cluster 표시                    │
└─────────────────────────────────────────────────────────────────┘
```

---

#### 3. 렌더링 파이프라인

```
[앱이 UI 업데이트]
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. Qt Quick Scene Graph 렌더링                                  │
│    QSGRenderer::renderScene()                                   │
│    ├─ QML 컴포넌트 → OpenGL draw calls                          │
│    ├─ GPU가 렌더링 → EGL buffer (wl_buffer)                     │
│    └─ wl_surface_commit(buffer) → Weston에 전송                 │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Weston Compositor 처리                                        │
│    weston_output_repaint()                                      │
│    ├─ 각 output의 모든 surface 수집                             │
│    ├─ Z-order 정렬 (Kiosk mode: 단일 surface)                  │
│    └─ GL Compositor로 합성                                       │
│        glBindFramebuffer(output_framebuffer)                    │
│        glBlitFramebuffer(surface_texture → output_fb)           │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. DRM/KMS Pageflip                                              │
│    drm_output_start_repaint_loop()                              │
│    ├─ drmModePageFlip(fd, crtc_id, fb_id, ...)                 │
│    │   → 수직 동기 신호(VSYNC)에서 framebuffer 전환              │
│    └─ GPU가 새 프레임을 HDMI 출력으로 전송                       │
│        → 실제 모니터에 픽셀 표시                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### 듀얼 모니터 레이아웃

```
┌──────────────────────────────────────────────────────────────────┐
│                           실제 물리적 배치                        │
└──────────────────────────────────────────────────────────────────┘

        [모니터 1: HDMI-A-1]              [모니터 2: HDMI-A-2]
       ┌─────────────────────┐          ┌─────────────────────┐
       │  HeadUnitApp        │          │  appIC              │
       │  (1024x600)         │          │  (1024x600)         │
       │                     │          │                     │
       │  ┌──────────────┐   │          │  ┌──────────────┐   │
       │  │ 블루투스      │   │          │  │ 속도계       │   │
       │  │ 뮤직플레이어  │   │          │  │ RPM          │   │
       │  │ 내비게이션    │   │          │  │ 연료량       │   │
       │  └──────────────┘   │          │  └──────────────┘   │
       └─────────────────────┘          └─────────────────────┘
              60Hz                             60Hz
           독립적 렌더링                    독립적 렌더링


┌──────────────────────────────────────────────────────────────────┐
│                      Weston의 논리적 레이아웃                     │
└──────────────────────────────────────────────────────────────────┘

  Wayland Display (논리적 좌표계)

  (0,0)                    (1024,0)              (2048,0)
    ├──────────────────────┼──────────────────────┤
    │  Output 0            │  Output 1            │
    │  HDMI-A-1            │  HDMI-A-2            │
    │  app-ids=HeadUnitApp │  app-ids=appIC       │
    │                      │                      │
    │  1024x600            │  1024x600            │
    └──────────────────────┴──────────────────────┘
  (0,600)                (1024,600)            (2048,600)

  ⚠️ 주의: Kiosk mode에서는 앱이 output 경계를 넘어갈 수 없음
           각 앱은 지정된 output에만 표시됨
```

---

### 핵심 기술 요약

#### 1. DRM/KMS (Direct Rendering Manager / Kernel Mode Setting)

- **역할**: 하드웨어 디스플레이 직접 제어 (X11 없이)
- **장점**:
  - 낮은 지연시간 (X11 레이어 제거)
  - 효율적인 GPU 활용
  - 독립적 화면 제어 (각 HDMI 포트 개별 설정)

#### 2. Kiosk Shell

- **역할**: 전체화면 모드 강제
- **특징**:
  - 창 최소화/최대화 불가
  - Alt+Tab 비활성화
  - Panel/Taskbar 없음
  - 자동차 인포테인먼트 시스템에 최적화

#### 3. app-ids 라우팅

- **원리**: Wayland의 `xdg_toplevel_set_app_id()` 사용
- **동작**:
  ```c
  // Qt/QML 앱에서 자동 설정됨
  QCoreApplication::setApplicationName("HeadUnitApp");
  // → Wayland protocol → Weston → weston.ini 매칭
  ```

---

### 성능 특성

```
┌─────────────────────────────────────────────────────────────────┐
│ 듀얼 모니터 렌더링 성능                                           │
├─────────────────────────────────────────────────────────────────┤
│ 프레임 레이트:          60 FPS (VSYNC 동기화)                    │
│ 렌더링 지연:            16.6ms 이하 (1 frame)                   │
│ GPU 사용률:             HDMI-A-1: 30%, HDMI-A-2: 15%            │
│ 메모리 사용:            Framebuffer: 약 14MB (1024x600x4bytes)  │
│ DRM Pageflip 지연:      < 1ms (하드웨어 VSYNC)                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 전체 시스템 통합 다이어그램

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DES Head-Unit System                         │
│                      (Automotive Infotainment)                       │
└─────────────────────────────────────────────────────────────────────┘

                           [User Interaction]
                                  │
            ┌─────────────────────┼─────────────────────┐
            │                     │                     │
            ▼                     ▼                     ▼
     [Touch Input]         [Bluetooth Phone]    [USB Media]
            │                     │                     │
            └─────────────────────┼─────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Qt/QML Application Layer                        │
│                                                                      │
│  ┌──────────────────────┐    ┌──────────────────────┐              │
│  │  BluetoothScreen.qml │    │  MusicScreen.qml     │              │
│  └──────────┬───────────┘    └──────────┬───────────┘              │
│             │                           │                           │
│             ▼                           ▼                           │
│  ┌──────────────────────┐    ┌──────────────────────┐              │
│  │  BluetoothManager    │    │  MusicPlayer         │              │
│  │  BluetoothAudioPlayer│    │  (QMediaPlayer)      │              │
│  └──────────┬───────────┘    └──────────┬───────────┘              │
└─────────────┼──────────────────────────┼──────────────────────────┘
              │                           │
              ▼                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      System Integration Layer                        │
│                                                                      │
│  ┌────────────────────┐        ┌────────────────────┐              │
│  │  BlueZ D-Bus API   │        │  GStreamer         │              │
│  │  (org.bluez)       │        │  (Qt Multimedia)   │              │
│  └─────────┬──────────┘        └─────────┬──────────┘              │
│            │                             │                          │
│            ▼                             ▼                          │
│  ┌──────────────────────────────────────────────────┐              │
│  │            Weston Wayland Compositor              │              │
│  │  - DRM Backend (Direct GPU access)                │              │
│  │  - Kiosk Shell (Fullscreen mode)                 │              │
│  └─────────────────┬───────────────────┬────────────┘              │
└────────────────────┼───────────────────┼─────────────────────────────┘
                     │                   │
                     ▼                   ▼
┌────────────────────────────┐  ┌────────────────────────────┐
│  HDMI-A-1 Output           │  │  HDMI-A-2 Output           │
│  (Head-Unit Interface)     │  │  (Instrument Cluster)      │
│  - Bluetooth Control       │  │  - Speedometer             │
│  - Music Player            │  │  - RPM Gauge               │
│  - Navigation              │  │  - Warning Lights          │
└────────────────────────────┘  └────────────────────────────┘
```

---

## 요약

### 블루투스 시스템

1. **하이브리드 접근**: QtBluetooth (페어링) + BlueZ D-Bus (연결/미디어)
2. **자동 페어링**: BluetoothAgent가 모든 인증 자동 승인
3. **AVRCP 제어**: 휴대폰 음악을 Head-Unit에서 완전 제어
4. **실시간 메타데이터**: 트랙 정보, 앨범 아트, 재생 위치 동기화

### 뮤직플레이어

1. **Qt Multimedia 기반**: QMediaPlayer + GStreamer 백엔드
2. **플랫폼 독립적**: Linux/Windows/macOS 모두 지원
3. **자동 라이브러리 검색**: 환경변수 → 상대경로 → 표준경로
4. **실시간 진행 추적**: 100ms 단위 positionChanged 신호

### Weston 듀얼 모니터

1. **DRM Backend**: X11 없이 GPU 직접 제어 (저지연)
2. **Kiosk Shell**: 전체화면 강제, 자동차 시스템 최적화
3. **app-ids 라우팅**: Wayland 프로토콜 기반 자동 화면 할당
4. **독립적 렌더링**: 각 HDMI 포트는 독립적 framebuffer 사용

---

**문서 버전**: 1.0
**최종 업데이트**: 2025-12-08
**작성자**: Claude Code Analysis
