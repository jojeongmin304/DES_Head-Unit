# 🎓 DES Head-Unit Yocto 프로젝트 완전 가이드

## 📋 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [Yocto 빌드 시스템 아키텍처](#2-yocto-빌드-시스템-아키텍처)
3. [디렉토리 구조 상세 분석](#3-디렉토리-구조-상세-분석)
4. [핵심 레이어 심층 분석](#4-핵심-레이어-심층-분석)
5. [빌드 설정 파일 완전 해부](#5-빌드-설정-파일-완전-해부)
6. [커스텀 레시피 상세 분석](#6-커스텀-레시피-상세-분석)
7. [시스템 통합 및 부팅 프로세스](#7-시스템-통합-및-부팅-프로세스)
8. [빌드 프로세스 단계별 설명](#8-빌드-프로세스-단계별-설명)

---

## 1. 프로젝트 개요

### 1.1 프로젝트 목적

**DES Head-Unit**은 자동차 헤드유닛과 계기판(Instrument Cluster)을 위한 **임베디드 Linux 시스템**입니다. Yocto Project를 사용하여 **Raspberry Pi 4 (64비트)** 하드웨어에서 동작하는 맞춤형 Linux 배포판을 생성합니다.

### 1.2 주요 기능

```
┌─────────────────────────────────────────────────────┐
│           DES Head-Unit 시스템 구성                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐         ┌──────────────┐          │
│  │  Head-Unit   │◄────────►│ Instrument   │          │
│  │  (HDMI-0)    │  D-Bus   │   Cluster    │          │
│  │  1024x600    │          │  (HDMI-1)    │          │
│  │              │          │  1024x600    │          │
│  └──────┬───────┘          └──────┬───────┘          │
│         │                         │                  │
│         └────────┬────────────────┘                  │
│                  │                                   │
│         ┌────────▼────────┐                          │
│         │  Qt 6 + Wayland │                          │
│         │    (Weston)     │                          │
│         └────────┬────────┘                          │
│                  │                                   │
│         ┌────────▼────────┐                          │
│         │  CAN Bus (can0, │                          │
│         │  can1) 500kbps  │                          │
│         └────────┬────────┘                          │
│                  │                                   │
│         ┌────────▼────────┐                          │
│         │   Bluetooth     │                          │
│         │   PulseAudio    │                          │
│         └─────────────────┘                          │
│                                                     │
│         Raspberry Pi 4 (64-bit)                     │
│         Linux Kernel 6.6.63                         │
│         systemd + Yocto Scarthgap                   │
└─────────────────────────────────────────────────────┘
```

### 1.3 기술 스택

| 계층 | 기술 | 버전/설명 |
|------|------|-----------|
| **하드웨어** | Raspberry Pi 4 | 64비트 ARM Cortex-A72 |
| **BSP** | meta-raspberrypi | GPU, 펌웨어, 커널 |
| **OS** | Yocto Linux | Scarthgap 릴리스 |
| **커널** | Linux | 6.6.63 |
| **Init** | systemd | 부트 관리자 |
| **Display** | Wayland + Weston | 듀얼 디스플레이 |
| **UI Framework** | Qt 6 | QML/Quick |
| **오디오** | PulseAudio | Bluetooth A2DP |
| **통신** | SocketCAN | MCP2518FD CAN-FD HAT |

---

## 2. Yocto 빌드 시스템 아키텍처

### 2.1 Yocto Project란?

**Yocto Project**는 임베디드 Linux 배포판을 생성하기 위한 **오픈소스 협업 프로젝트**입니다. 다음과 같은 도구를 제공합니다:

- **BitBake**: 태스크 실행 엔진 (Make와 유사하지만 더 강력함)
- **OpenEmbedded-Core**: 핵심 레시피 모음
- **Poky**: 참조 배포판

```
┌────────────────────────────────────────────────────┐
│              Yocto 아키텍처 개념도                    │
└────────────────────────────────────────────────────┘

        사용자가 실행: bitbake des-image
                        │
                        ▼
        ┌───────────────────────────────┐
        │       BitBake 엔진             │
        │  (레시피 파싱, 의존성 해결,       │
        │   태스크 스케줄링)                │
        └───────────────┬───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │   레이어 메타데이터 수집          │
        │  (*.bb, *.bbappend, *.conf)   │
        └───────────────┬───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │   소스 다운로드 (git, wget)     │
        │   패치 적용                    │
        └───────────────┬───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │   컴파일 (gcc, 크로스 컴파일)    │
        │   빌드 (make, cmake, ninja)   │
        └───────────────┬───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │   패키징 (RPM, DEB, IPK)       │
        └───────────────┬───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │   루트 파일시스템 조립          │
        │   (rootfs 생성)                │
        └───────────────┬───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │   이미지 생성                  │
        │   (.wic.bz2, .rpi-sdimg)      │
        └───────────────────────────────┘
```

### 2.2 레이어 개념

**레이어(Layer)**는 Yocto의 핵심 개념으로, 레시피와 설정을 모듈화하여 관리합니다.

```
레이어의 역할:
┌──────────────────────────────────────────────┐
│ meta-custom/meta-env                         │
│ 역할: 배포판 정책, 이미지 레시피             │
│ 우선순위: 7                                  │
└──────────────────────────────────────────────┘
                    ▲
                    │ 확장
┌──────────────────────────────────────────────┐
│ meta-qt6                                     │
│ 역할: Qt 6 라이브러리 제공                    │
│ 우선순위: 6                                  │
└──────────────────────────────────────────────┘
                    ▲
                    │ 확장
┌──────────────────────────────────────────────┐
│ meta-raspberrypi                             │
│ 역할: RPi4 BSP (펌웨어, 커널, GPU)            │
│ 우선순위: 5                                  │
└──────────────────────────────────────────────┘
                    ▲
                    │ 확장
┌──────────────────────────────────────────────┐
│ poky/meta (OpenEmbedded-Core)                │
│ 역할: 기본 Linux 패키지 (glibc, gcc 등)       │
│ 우선순위: 5                                  │
└──────────────────────────────────────────────┘
```

**레이어 우선순위 규칙**:
- 우선순위가 높을수록 나중에 파싱됨
- 같은 파일을 여러 레이어에서 정의하면 높은 우선순위 레이어가 이김
- `.bbappend` 파일로 다른 레이어의 레시피를 확장 가능

---

## 3. 디렉토리 구조 상세 분석

### 3.1 전체 디렉토리 트리

```
/home/seame/DES_Head-Unit/
└── yocto-workspace/
    ├── poky/                      # [코어 레이어] Yocto 참조 시스템
    │   ├── meta/                  # OpenEmbedded-Core
    │   ├── meta-poky/             # Poky 배포판 설정
    │   ├── meta-yocto-bsp/        # 참조 BSP
    │   ├── bitbake/               # BitBake 빌드 엔진
    │   └── oe-init-build-env      # 환경 초기화 스크립트
    │
    ├── meta-openembedded/         # [커뮤니티 레이어] 확장 패키지
    │   ├── meta-oe/               # 범용 유틸리티 (curl, git 등)
    │   ├── meta-python/           # Python 패키지
    │   ├── meta-networking/       # 네트워킹 도구
    │   ├── meta-multimedia/       # 멀티미디어 (GStreamer 등)
    │   └── meta-gnome/            # GNOME 관련
    │
    ├── meta-qt6/                  # [Qt 레이어] Qt 6 프레임워크
    │   ├── recipes-qt/            # Qt 모듈 레시피
    │   └── classes/               # Qt 빌드 클래스
    │
    ├── meta-raspberrypi/          # [BSP 레이어] Raspberry Pi 지원
    │   ├── recipes-bsp/           # 부트로더, 펌웨어
    │   ├── recipes-kernel/        # Linux 커널
    │   └── conf/machine/          # 머신 설정 (raspberrypi4-64.conf)
    │
    └── meta-custom/               # [커스텀 레이어] DES 프로젝트
        ├── meta-env/              # 환경 설정 레이어
        │   ├── conf/
        │   │   ├── layer.conf     # 레이어 설정
        │   │   └── distro/
        │   │       └── des.conf   # DES 배포판 정의
        │   ├── recipes-core/
        │   │   └── images/
        │   │       └── des-image.bb  # 최종 이미지 레시피
        │   ├── recipes-bsp/
        │   │   └── bootfiles/
        │   │       └── rpi-config_%.bbappend  # config.txt 설정
        │   ├── recipes-kernel/
        │   │   └── linux/
        │   │       └── linux-raspberrypi_%.bbappend  # 커널 확장
        │   ├── recipes-graphics/
        │   │   └── wayland/
        │   │       └── weston-init.bbappend  # Weston 설정
        │   └── recipes-connectivity/
        │       └── bluez5/
        │           └── bluez5_%.bbappend  # Bluetooth 설정
        │
        ├── meta-app/              # 애플리케이션 레이어
        │   └── recipes-des/
        │       ├── headunit/
        │       │   └── headunit.bb  # HeadUnit Qt 앱
        │       └── instrument-cluster/
        │           └── instrument-cluster.bb  # 계기판 앱
        │
        └── meta-piracer/          # 하드웨어 통합 레이어
            ├── recipes-support/
            │   ├── can/
            │   │   ├── can0.bb    # CAN0 인터페이스 설정
            │   │   └── can1.bb    # CAN1 인터페이스 설정
            │   └── piracer-controller/
            │       └── piracer-controller.bb  # PiRacer 컨트롤러
            └── recipes-python/
                └── adafruit/      # Adafruit Python 라이브러리
```

### 3.2 빌드 디렉토리 구조

```
build-des/                         # BitBake 작업 디렉토리
├── conf/
│   ├── local.conf                # 로컬 빌드 설정
│   ├── bblayers.conf             # 레이어 목록
│   └── templateconf.cfg          # 템플릿 설정
│
├── downloads/                    # 소스 다운로드 캐시
│   └── git2/                     # Git 저장소 미러
│
├── sstate-cache/                 # 빌드 캐시 (재사용 가능)
│   └── ??/                       # 해시 기반 저장소
│
└── tmp-glibc/                    # 임시 빌드 파일
    ├── deploy/
    │   ├── images/
    │   │   └── raspberrypi4-64/
    │   │       ├── des-image-*.wic.bz2     # 최종 이미지
    │   │       ├── des-image-*.rpi-sdimg   # SD 카드 이미지
    │   │       ├── Image                   # 커널 이미지
    │   │       └── *.dtb                   # 디바이스 트리
    │   └── rpm/                  # RPM 패키지
    │
    ├── work/                     # 각 패키지 빌드 작업
    │   └── raspberrypi4_64-oe-linux/
    │       └── headunit/
    │           └── 1.0-r0/       # 레시피 버전별 작업 공간
    │
    └── sysroots-components/      # 크로스 컴파일 환경
        └── raspberrypi4_64/      # 타겟 sysroot
```

**각 디렉토리가 존재하는 이유**:

1. **downloads/**: 소스 코드를 한 번만 다운로드하고 재사용 (네트워크 절약)
2. **sstate-cache/**: 빌드 결과를 캐싱하여 재빌드 시간 단축 (시간 절약)
3. **tmp-glibc/work/**: 각 패키지를 독립된 환경에서 빌드 (충돌 방지)
4. **tmp-glibc/deploy/**: 최종 산출물을 한 곳에 모음 (배포 편의성)

---

## 4. 핵심 레이어 심층 분석

### 4.1 meta-env: 배포판 레이어

**역할**: DES 배포판의 정책과 시스템 이미지를 정의합니다.

#### 4.1.1 des.conf - 배포판 설정

**파일**: `meta-custom/meta-env/conf/distro/des.conf`

```bash
DISTRO = "des"
DISTRO_NAME = "DES Head-Unit"
DISTRO_VERSION = "1.0"
```

**왜 이 코드가 있는가?**
- Yocto는 여러 배포판을 지원하므로 고유 식별자가 필요
- `DISTRO` 변수를 설정하면 `local.conf`에서 `DISTRO ?= "des"`로 선택 가능

```bash
VIRTUAL-RUNTIME_init_manager = "systemd"
```

**세부 설명**:
- `VIRTUAL-RUNTIME_init_manager`: 어떤 init 시스템을 사용할지 결정
- 선택 가능한 값: `systemd`, `sysvinit`, `busybox`
- **왜 systemd?**
  - 병렬 부팅으로 부팅 속도 향상
  - 의존성 관리 (서비스 순서 제어)
  - 디바이스 자동 감지 (udev 통합)
  - D-Bus 통합으로 IPC 간소화

```bash
DISTRO_FEATURES:append = " systemd wayland opengl pulseaudio bluetooth pam usrmerge"
```

**각 기능이 필요한 이유**:

| Feature | 설명 | 사용 이유 |
|---------|------|-----------|
| `systemd` | systemd init 시스템 | 서비스 관리, 부팅 제어 |
| `wayland` | Wayland 디스플레이 서버 | X11 대신 경량 GPU 가속 |
| `opengl` | OpenGL 지원 | Qt Quick의 2D/3D 렌더링 |
| `pulseaudio` | PulseAudio 오디오 서버 | Bluetooth 오디오 라우팅 |
| `bluetooth` | Bluetooth 스택 | 차량 페어링, 핸즈프리 |
| `pam` | Pluggable Auth Modules | systemd 인증 지원 |
| `usrmerge` | /bin → /usr/bin 병합 | 최신 Linux 표준 준수 |

```bash
QT_QPA_PLATFORM ?= "wayland"
```

**QPA (Qt Platform Abstraction)**:
- Qt가 다양한 플랫폼을 지원하는 추상화 레이어
- 가능한 값: `wayland`, `eglfs`, `xcb` (X11)
- **Wayland 선택 이유**:
  - X11보다 낮은 레이턴시
  - 듀얼 디스플레이 지원 용이
  - GPU 직접 렌더링

```bash
PACKAGE_CLASSES ?= "package_rpm"
```

**패키지 관리 시스템**:
- `package_rpm`: Red Hat/Fedora 스타일
- 대안: `package_deb` (Debian/Ubuntu), `package_ipk` (OpenWrt)
- **RPM 선택 이유**: Yocto 기본값, 잘 테스트됨

```bash
SYSTEMD_DEFAULT_TARGET = "graphical.target"
```

**systemd 타겟**:
- `multi-user.target`: 콘솔만 (GUI 없음)
- `graphical.target`: GUI 포함
- 헤드유닛은 화면이 필요하므로 `graphical.target` 필수

---

### 4.2 meta-app: 애플리케이션 레이어

#### 4.2.1 headunit.bb - HeadUnit 애플리케이션

**파일**: `meta-custom/meta-app/recipes-des/headunit/headunit.bb`

```bash
SUMMARY = "Qt 6 modular head unit application"
LICENSE = "CLOSED"
```

**라이센스 설정**:
- `LICENSE = "CLOSED"`: 독점 소프트웨어 (오픈소스 아님)
- 오픈소스라면 `GPL-2.0`, `MIT` 등 명시
- Yocto는 라이센스 호환성을 자동 검사

```bash
SRC_URI = "file://headunit.service \
           file://rfkill-unblock.service \
           file://headunit-bluetooth.conf \
"
```

**SRC_URI 동작 원리**:
- `file://` 프로토콜: 레시피와 같은 디렉토리의 `files/` 폴더에서 검색
- 다른 프로토콜: `git://`, `https://`, `ftp://`
- BitBake가 파일을 `${WORKDIR}`로 자동 복사

**왜 이런 파일들이 필요한가?**:

1. **headunit.service**: systemd 서비스 유닛
   - 시스템 부팅 시 HeadUnit 자동 시작
   - Weston (Wayland compositor) 대기

2. **rfkill-unblock.service**: Bluetooth 활성화
   - Raspberry Pi는 기본적으로 Bluetooth가 비활성화될 수 있음
   - `rfkill unblock bluetooth` 명령 실행

3. **headunit-bluetooth.conf**: D-Bus 권한
   - HeadUnit이 BlueZ (Bluetooth 스택)와 통신 허용

```bash
S = "${WORKDIR}/HeadUnit"
```

**S 변수 (소스 디렉토리)**:
- BitBake 컨벤션: `${WORKDIR}/${BPN}-${PV}` (예: `headunit-1.0`)
- 여기서는 외부 소스를 사용하므로 재정의

```bash
inherit qt6-cmake systemd
```

**클래스 상속의 의미**:

1. **qt6-cmake**:
   - Qt 6 프로젝트를 CMake로 빌드하는 헬퍼 클래스
   - 자동으로 `cmake`, `ninja`, Qt 경로 설정
   - `do_configure`, `do_compile` 태스크 자동 구현

2. **systemd**:
   - systemd 서비스 설치 및 활성화
   - `SYSTEMD_SERVICE` 변수 파싱
   - `do_install` 후 서비스 링크 생성

```bash
HEADUNIT_SRC ?= "${TOPDIR}/../../Head-Unit"
```

**외부 소스 경로**:
- `${TOPDIR}`: `build-des` 디렉토리
- `../../`: 프로젝트 루트로 이동
- 개발 중에는 소스를 Git submodule 대신 직접 참조

**장점**: 코드 수정 후 즉시 재빌드 가능
**단점**: 배포 시 재현 불가 (Git 커밋 해시 필요)

```bash
DEPENDS = "\
    qtbase \
    qtdeclarative \
    qtdeclarative-native \
    ...
"
```

**DEPENDS vs RDEPENDS**:

| 변수 | 시점 | 설명 |
|------|------|------|
| `DEPENDS` | 빌드 타임 | 컴파일 시 필요한 헤더/라이브러리 |
| `RDEPENDS` | 런타임 | 실행 시 필요한 공유 라이브러리 |

**예시**:
- `qtbase`: Qt 헤더 파일 (빌드 시)
- `qtbase`: libQt6Core.so (런타임 시)

**-native 접미사**:
- `qtdeclarative-native`: 호스트 PC에서 실행되는 도구
- 예: `qmlcachegen` (QML 컴파일러)
- 크로스 컴파일 환경에서 필수

```bash
do_prepare_sources() {
    src="${HEADUNIT_SRC}"
    if [ ! -d "${src}" ]; then
        bberror "HeadUnit sources not found at ${src}"
        exit 1
    fi

    rm -rf ${S}
    mkdir -p ${S}
    cp -a "${src}"/. ${S}/

    # Drop developer-only build directories
    find ${S} -maxdepth 1 -type d -name "build*" -exec rm -rf {} +
    rm -rf ${S}/.qtc_clangd
}
```

**커스텀 태스크 분석**:

1. **소스 검증**:
   - `bberror`: BitBake 오류 메시지
   - 소스가 없으면 빌드 중단 (조기 실패)

2. **클린 복사**:
   - `rm -rf ${S}`: 이전 빌드 잔여물 제거
   - `cp -a`: 권한 및 심볼릭 링크 유지

3. **개발 파일 제거**:
   - `build*`: CMake 빌드 디렉토리
   - `.qtc_clangd`: Qt Creator LSP 캐시
   - **이유**: 이미지 크기 절약, 재현성 보장

```bash
addtask prepare_sources after do_unpack before do_patch
```

**태스크 순서 지정**:

```
기본 태스크 체인:
do_fetch → do_unpack → do_patch → do_configure → do_compile → do_install → do_package

커스텀 태스크 삽입:
do_fetch → do_unpack → [do_prepare_sources] → do_patch → ...
```

**왜 do_unpack 후?**
- `do_unpack`은 `SRC_URI`의 파일을 `${WORKDIR}`에 압축 해제
- 외부 소스 복사는 압축 해제 후에 수행

**왜 do_patch 전?**
- 패치는 소스가 준비된 후 적용되어야 함

```bash
do_install:append() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/headunit.service ${D}${systemd_system_unitdir}/
    ...
}
```

**install 명령어 옵션**:
- `install -d`: 디렉토리 생성 (`mkdir -p`와 유사)
- `install -m 0644`: 파일 복사 + 권한 설정 (rw-r--r--)
- `${D}`: Destination, 가짜 루트 (`/`의 스테이징 영역)

**왜 ${D}를 사용?**
- 실제 시스템 `/`에 직접 쓰면 호스트가 손상됨
- `${D}`는 `tmp-glibc/work/.../image/` 디렉토리
- 나중에 rootfs에 병합됨

```bash
FILES:${PN} += "\
    ${bindir}/HeadUnitApp \
    ${datadir}/headunit \
    ${systemd_system_unitdir}/headunit.service \
    ...
"
```

**FILES 변수의 역할**:
- 어떤 파일을 패키지에 포함할지 명시
- 명시되지 않은 파일은 경고 발생 (QA 검사)

**디렉토리 변수**:
- `${bindir}`: `/usr/bin`
- `${datadir}`: `/usr/share`
- `${systemd_system_unitdir}`: `/usr/lib/systemd/system`

```bash
SYSTEMD_SERVICE:${PN} = "headunit.service rfkill-unblock.service"
SYSTEMD_AUTO_ENABLE = "enable"
```

**systemd 통합**:
- `SYSTEMD_SERVICE`: 설치할 서비스 나열
- `SYSTEMD_AUTO_ENABLE = "enable"`: 부팅 시 자동 시작
  - `systemctl enable headunit.service` 자동 실행
  - `/etc/systemd/system/graphical.target.wants/` 심볼릭 링크 생성

---

### 4.3 meta-piracer: 하드웨어 통합 레이어

#### 4.3.1 can0.bb - CAN 인터페이스 설정

**파일**: `meta-custom/meta-piracer/recipes-support/can/can0.bb`

```bash
SUMMARY = "Systemd unit to bring up can0"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=..."
```

**LICENSE 체크섬**:
- Yocto는 라이센스 텍스트의 MD5 해시를 검증
- **왜?**: 라이센스가 변경되지 않았음을 보장
- `${COMMON_LICENSE_DIR}`: 표준 라이센스 모음 (`poky/meta/files/common-licenses/`)

```bash
SRC_URI = "file://can0.service"
```

**can0.service 내용** (추정):
```ini
[Unit]
Description=CAN interface can0
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/ip link set can0 type can bitrate 500000
ExecStart=/usr/sbin/ip link set can0 up

[Install]
WantedBy=multi-user.target
```

**각 줄의 의미**:

1. **After=network.target**: 네트워크 초기화 후 실행
2. **Type=oneshot**: 한 번만 실행하고 종료
3. **RemainAfterExit=yes**: 종료 후에도 "활성" 상태 유지
4. **bitrate 500000**: CAN 버스 속도 500kbps
   - 자동차 표준: 500kbps (고속), 125kbps (저속)

```bash
inherit systemd
```

**systemd 클래스가 자동으로 수행하는 작업**:
1. `${D}${systemd_system_unitdir}`에서 `.service` 파일 검색
2. 패키지에 포함 (`FILES:${PN}`)
3. postinst 스크립트에서 `systemctl enable` 실행

```bash
SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "can0.service"
```

**결과**:
- 첫 부팅 시 자동으로 CAN0 인터페이스 활성화
- 이후 부팅에서도 자동으로 up 상태 유지

---

## 5. 빌드 설정 파일 완전 해부

### 5.1 bblayers.conf - 레이어 등록

**파일**: `build-des/conf/bblayers.conf`

```bash
POKY_BBLAYERS_CONF_VERSION = "2"
```

**버전 관리**:
- Yocto 릴리스 간 `bblayers.conf` 형식이 변경될 수 있음
- 버전 불일치 시 BitBake가 경고

```bash
BBPATH = "${TOPDIR}"
```

**BBPATH의 역할**:
- BitBake가 설정 파일을 검색하는 경로
- 일반적으로 빌드 디렉토리 (build-des)

```bash
BBFILES ?= ""
```

**BBFILES**:
- 레시피 파일(`.bb`)의 glob 패턴
- 레이어의 `layer.conf`에서 설정되므로 여기서는 비어 있음

```bash
BBLAYERS ?= " \
  ${TOPDIR}/../poky/meta \
  ${TOPDIR}/../poky/meta-poky \
  ${TOPDIR}/../poky/meta-yocto-bsp \
  ${TOPDIR}/../meta-openembedded/meta-oe \
  ${TOPDIR}/../meta-openembedded/meta-python \
  ${TOPDIR}/../meta-openembedded/meta-networking \
  ${TOPDIR}/../meta-raspberrypi \
  ${TOPDIR}/../meta-qt6 \
  ${TOPDIR}/../meta-custom/meta-env \
  ${TOPDIR}/../meta-custom/meta-app \
  ${TOPDIR}/../meta-custom/meta-piracer \
  "
```

**레이어 순서의 중요성**:

```
파싱 순서 (위 → 아래):
1. poky/meta                (기본 레시피)
2. poky/meta-poky           (Poky 정책)
3. meta-raspberrypi         (RPi 오버라이드)
4. meta-qt6                 (Qt 추가)
5. meta-custom/meta-env     (DES 오버라이드)
```

**동작 예시**:
- `poky/meta`에서 `weston` 레시피 정의
- `meta-custom/meta-env/recipes-graphics/wayland/weston-init.bbappend`가 확장
- 결과: DES 맞춤 Weston 설정 적용

---

### 5.2 local.conf - 빌드 설정

**파일**: `build-des/conf/local.conf`

#### 5.2.1 머신 선택

```bash
MACHINE ??= "raspberrypi4-64"
```

**??= 연산자**:
- "약한 기본값" (weak default assignment)
- 환경 변수로 오버라이드 가능:
  ```bash
  MACHINE=qemux86-64 bitbake des-image
  ```

**raspberrypi4-64의 의미**:
- `meta-raspberrypi/conf/machine/raspberrypi4-64.conf`를 로드
- ARM Cortex-A72 크로스 컴파일러 선택
- GPU 펌웨어, 디바이스 트리 설정

#### 5.2.2 배포판 선택

```bash
DISTRO ?= "des"
```

**배포판 로딩 과정**:
1. `DISTRO = "des"` 설정
2. BitBake가 `meta-custom/meta-env/conf/distro/des.conf` 검색
3. `des.conf`의 설정 적용 (systemd, Wayland 등)

#### 5.2.3 디버그 기능

```bash
EXTRA_IMAGE_FEATURES ?= "debug-tweaks"
```

**debug-tweaks가 하는 일**:
1. **root 로그인 비밀번호 제거**:
   - `/etc/shadow`에서 root 비밀번호 해시 삭제
   - SSH로 비밀번호 없이 로그인 가능

2. **SSH 서버 자동 시작**:
   - `ssh-server-openssh` 패키지 포함

3. **빈 비밀번호 허용**:
   - PAM 설정 수정

**주의**: 프로덕션 이미지에서는 제거해야 함!

#### 5.2.4 빌드 통계

```bash
USER_CLASSES ?= "buildstats"
```

**buildstats 클래스**:
- 각 태스크의 CPU 시간, 디스크 I/O 측정
- `tmp-glibc/buildstats/` 디렉토리에 저장
- 병목 지점 분석 가능

#### 5.2.5 패치 해결

```bash
PATCHRESOLVE = "noop"
```

**패치 충돌 처리**:
- `noop`: 실패 시 즉시 중단 (기본값)
- `user`: 터미널 열고 사용자 개입 요청

**왜 noop?**
- CI/CD 환경에서 자동 빌드 중단 필요
- 수동 개입은 재현성 저해

#### 5.2.6 디스크 모니터링

```bash
BB_DISKMON_DIRS ??= "\
    STOPTASKS,${TMPDIR},1G,100K \
    STOPTASKS,${DL_DIR},1G,100K \
    STOPTASKS,${SSTATE_DIR},1G,100K \
    STOPTASKS,/tmp,100M,100K \
    HALT,${TMPDIR},100M,1K \
    HALT,${DL_DIR},100M,1K \
    HALT,${SSTATE_DIR},100M,1K \
    HALT,/tmp,10M,1K"
```

**형식**: `동작,경로,최소_공간,최소_inode`

**동작 유형**:
- `STOPTASKS`: 새 태스크 시작 중단 (진행 중인 태스크는 계속)
- `HALT`: 즉시 모든 빌드 중단

**예시**:
- `${TMPDIR}`에 1GB 미만 남으면 → 새 태스크 중단
- `${TMPDIR}`에 100MB 미만 남으면 → 즉시 중단

**왜 필요한가?**
- 디스크 풀로 인한 파일 손상 방지
- Yocto 빌드는 50GB+ 사용 가능

#### 5.2.7 빌드 성능 튜닝

```bash
# xz 압축기 메모리 제한
XZ_DEFAULTS = "-T0 -M768MiB"
```

**XZ 압축 옵션**:
- `-T0`: 모든 CPU 코어 사용
- `-M768MiB`: 최대 768MB 메모리 사용
  - 기본값 없으면 수 GB 사용 가능
  - OOM killer 트리거 방지

```bash
# 병렬 빌드 제한
BB_NUMBER_THREADS = "4"
PARALLEL_MAKE = "-j 4"
```

**병렬성 제어**:

| 변수 | 적용 대상 | 설명 |
|------|-----------|------|
| `BB_NUMBER_THREADS` | BitBake 태스크 | 동시에 실행할 레시피 수 |
| `PARALLEL_MAKE` | make 명령 | 각 레시피 내 병렬 컴파일 |

**예시**:
- `BB_NUMBER_THREADS = "4"`: 4개 레시피 동시 빌드
- `PARALLEL_MAKE = "-j 4"`: 각 레시피에서 4개 파일 동시 컴파일

**최적값 계산**:
```
BB_NUMBER_THREADS ≈ CPU 코어 수
PARALLEL_MAKE ≈ CPU 코어 수
RAM 사용량 ≈ BB_NUMBER_THREADS × 2GB
```

**이 프로젝트의 선택 (4코어)**:
- 16코어 CPU에서 4개만 사용
- **이유**: 메모리 부족 방지, 시스템 응답성 유지

#### 5.2.8 작업 공간 정리

```bash
RM_WORK_EXCLUDE += "qtbase qtdeclarative"
INHERIT += "rm_work"
```

**rm_work 클래스**:
- 각 패키지 빌드 후 소스/빌드 디렉토리 삭제
- 디스크 사용량 50% 이상 절감

**RM_WORK_EXCLUDE**:
- Qt 패키지는 제외 (재빌드 시간 김)
- 디버깅 시 소스 코드 유지

#### 5.2.9 Qt 6 Wayland 지원

```bash
# Enable Qt Wayland plugins
PACKAGECONFIG:append:pn-qtbase = " wayland gles2 kms gbm"
```

**PACKAGECONFIG 메커니즘**:
- 각 레시피는 선택적 기능을 `PACKAGECONFIG`로 정의
- 런타임에 기능 추가/제거 가능

**qtbase의 Wayland 옵션**:
- `wayland`: Wayland 클라이언트 플러그인
- `gles2`: OpenGL ES 2.0 (GPU 가속)
- `kms`: Kernel Mode Setting (직접 GPU 제어)
- `gbm`: Generic Buffer Management (버퍼 공유)

**동작 원리**:
```
Qt Application
      ↓
Wayland Protocol
      ↓
  Weston
      ↓
   KMS/DRM (커널)
      ↓
VideoCore GPU (RPi4)
```

```bash
DISTRO_FEATURES:append = " wayland bluetooth"
```

**전역 기능 활성화**:
- `wayland`: Wayland 지원 패키지만 빌드
- `bluetooth`: BlueZ 스택 포함

```bash
# Remove X11 to prevent conflicts
DISTRO_FEATURES:remove = " x11"
```

**X11 제거 이유**:
- Wayland와 X11은 상호 배타적
- X11 라이브러리는 크기가 큼 (수십 MB)
- RPi4에서 X11은 성능이 떨어짐

#### 5.2.10 파일시스템 호환성

```bash
EXTRA_IMAGECMD:ext4 = "-O ^metadata_csum_seed"
```

**ext4 체크섬 비활성화**:
- Raspberry Pi 부트로더는 오래된 e2fsprogs 사용
- `metadata_csum_seed` 기능 인식 불가
- 비활성화하지 않으면 부팅 실패

**형식**: `-O ^FEATURE` (캐럿은 제거를 의미)

---

## 6. 커스텀 레시피 상세 분석

### 6.1 des-image.bb - 최종 이미지 레시피

**파일**: `meta-custom/meta-env/recipes-core/images/des-image.bb`

```bash
inherit core-image
inherit sdcard_image-rpi
```

**클래스 상속 체인**:

```
des-image.bb
    ↓ inherit core-image
core-image.bbclass
    ↓ inherit image
image.bbclass
    (기본 이미지 생성 로직)
    ↓
sdcard_image-rpi.bbclass
    (RPi SD 카드 레이아웃)
```

**core-image 클래스가 제공하는 것**:
- `do_rootfs`: rootfs 조립
- `do_image`: 파일시스템 이미지 생성
- `IMAGE_FEATURES` 처리

**sdcard_image-rpi 클래스**:
- RPi 부트 파티션 생성 (FAT32)
- 루트 파티션 생성 (ext4)
- `config.txt`, `cmdline.txt` 설치

```bash
BOOT_SPACE = "98304"
```

**부트 파티션 크기**:
- 단위: KB (98304KB = 96MB)
- 내용:
  - GPU 펌웨어 (`start4.elf`, `fixup4.dat`)
  - 커널 이미지 (`Image`)
  - 디바이스 트리 (`*.dtb`, `*.dtbo`)
  - `config.txt`, `cmdline.txt`

**왜 96MB?**
- 기본값 40MB는 부족할 수 있음
- 커널 + DTB + 펌웨어 = 약 50-60MB
- 여유 공간 필요 (업데이트용)

```bash
IMAGE_FEATURES += "ssh-server-openssh package-management"
```

**이미지 기능**:
- `ssh-server-openssh`: OpenSSH 서버 포함
- `package-management`: RPM 도구 포함
  - `rpm`, `dnf`, `smart`
  - 런타임에 패키지 설치 가능

```bash
IMAGE_INSTALL:append = " \
    packagegroup-core-buildessential \
    iproute2 can-utils \
    wpa-supplicant \
    connman connman-client \
    ...
"
```

**패키지 선택 분석**:

| 패키지 | 역할 | 필요 이유 |
|--------|------|-----------|
| `packagegroup-core-buildessential` | gcc, make, 헤더 | 온디바이스 개발 |
| `iproute2` | ip, ss 명령 | 네트워크 설정 |
| `can-utils` | cansend, candump | CAN 디버깅 |
| `wpa-supplicant` | WiFi 인증 | WiFi 연결 |
| `connman` | 네트워크 관리자 | WiFi/Ethernet 통합 |
| `qtbase` | Qt Core | HeadUnit 실행 |
| `qtwayland` | Wayland 플러그인 | Qt GUI 표시 |
| `qtmultimedia` | 오디오/비디오 | 미디어 재생 |
| `gstreamer1.0-*` | 멀티미디어 파이프라인 | 코덱 지원 |
| `pulseaudio` | 오디오 서버 | Bluetooth 오디오 |
| `bluez-alsa` | Bluetooth ALSA 브리지 | A2DP 싱크 |
| `fontconfig` | 폰트 관리 | Qt 텍스트 렌더링 |
| `ttf-dejavu-*` | 폰트 파일 | 기본 글꼴 |
| `ttf-noto-emoji-color` | 이모지 폰트 | 이모지 표시 |
| `weston` | Wayland compositor | 디스플레이 서버 |
| `libinput` | 입력 처리 | 터치/마우스 |
| `evtest` | 입력 디버깅 | 이벤트 모니터링 |
| `i2c-dev-autoload` | I2C 드라이버 | PiRacer I2C 디바이스 |
| `headunit` | HeadUnit 앱 | 메인 UI |
| `instrument-cluster` | 계기판 앱 | 보조 디스플레이 |
| `des-gear-dbus-config` | D-Bus 설정 | 기어 변속 통신 |
| `can1` | CAN1 활성화 | CAN 버스 |
| `piracer-controller` | 게임패드 컨트롤러 | 차량 제어 |
| `plymouth` | 부팅 화면 | 로고 표시 |
| `wifi-auto-enable` | WiFi 자동 활성화 | 개발 편의성 |

```bash
add_users_to_groups() {
    sed -i 's/root:x:0:0:root:\/root:\/bin\/sh/root:x:0:0:root:\/root:\/bin\/bash/' ${IMAGE_ROOTFS}/etc/passwd
    groupadd bluetooth -R ${IMAGE_ROOTFS}
    usermod -a -G audio root -R ${IMAGE_ROOTFS}
    usermod -a -G bluetooth pulse -R ${IMAGE_ROOTFS} || true
    usermod -a -G audio bluealsa -R ${IMAGE_ROOTFS} || true
    usermod -a -G bluetooth bluealsa -R ${IMAGE_ROOTFS} || true
}
```

**각 명령의 필요성**:

1. **root 셸 변경**:
   ```bash
   /bin/sh → /bin/bash
   ```
   - 이유: Bash는 자동 완성, 히스토리 등 개발자 친화적

2. **bluetooth 그룹 생성**:
   - BlueZ는 `bluetooth` 그룹 멤버만 제어 가능
   - D-Bus 정책과 연동

3. **root → audio 그룹**:
   - root가 오디오 디바이스 직접 접근
   - 디버깅 시 필요

4. **pulse → bluetooth 그룹**:
   - PulseAudio가 BlueZ와 통신
   - A2DP 프로파일 활성화

5. **bluealsa → audio, bluetooth**:
   - `bluez-alsa` 데몬이 오디오 라우팅
   - ALSA PCM 디바이스 생성

**|| true 의미**:
- 사용자가 없으면 에러 무시
- 스크립트 계속 실행

```bash
enable_pulseaudio_service() {
    if [ -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/pulseaudio.service ]; then
        mkdir -p ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants
        ln -sf /usr/lib/systemd/system/pulseaudio.service \
               ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants/pulseaudio.service
        bbnote "Enabled pulseaudio.service"
    else
        bbwarn "pulseaudio.service not found, skipping enablement"
    fi
}
```

**수동 서비스 활성화 이유**:
- PulseAudio 레시피가 systemd 통합이 없을 수 있음
- 명시적으로 심볼릭 링크 생성
- `systemctl enable`과 동일한 효과

```bash
ROOTFS_POSTPROCESS_COMMAND += " add_users_to_groups; enable_pulseaudio_service; "
```

**후처리 명령**:
- rootfs 조립 후, 이미지 생성 전 실행
- 여러 함수를 세미콜론으로 연결
- 실행 순서 보장됨

```bash
IMAGE_FSTYPES += "wic.bz2 rpi-sdimg"
```

**출력 형식**:
- `wic.bz2`: WIC (Yocto Image Creator) 압축 이미지
  - 범용 파티션 레이아웃 도구
  - `bmaptool`로 빠른 플래싱 가능

- `rpi-sdimg`: Raspberry Pi SD 카드 원시 이미지
  - `dd`로 직접 쓰기 가능
  - `balenaEtcher` 호환

**WIC vs rpi-sdimg**:
- WIC: 압축되어 전송 빠름
- rpi-sdimg: 플래싱 간단 (압축 해제 불필요)

---

### 6.2 커널 및 디바이스 트리 설정

#### 6.2.1 linux-raspberrypi_%.bbappend

**파일**: `meta-custom/meta-env/recipes-kernel/linux/linux-raspberrypi_%.bbappend`

```bash
KERNEL_DEVICETREE:append = " \
    overlays/seeed-can-fd-hat-v2.dtbo \
"
```

**디바이스 트리 오버레이**:
- 베이스 DTB: `bcm2711-rpi-4-b.dtb` (RPi4 하드웨어 설명)
- 오버레이: 추가 하드웨어 동적 활성화

**seeed-can-fd-hat-v2.dtbo 내용** (예상):
```dts
/dts-v1/;
/plugin/;

/ {
    compatible = "brcm,bcm2711";

    fragment@0 {
        target = <&spi0>;
        __overlay__ {
            status = "okay";
            can0: mcp2518fd@0 {
                compatible = "microchip,mcp2518fd";
                reg = <0>;
                clocks = <&can0_osc>;
                interrupt-parent = <&gpio>;
                interrupts = <25 IRQ_TYPE_LEVEL_LOW>;
                spi-max-frequency = <10000000>;
            };
        };
    };

    fragment@1 {
        target-path = "/";
        __overlay__ {
            can0_osc: can0_osc {
                compatible = "fixed-clock";
                #clock-cells = <0>;
                clock-frequency = <40000000>;
            };
        };
    };
};
```

**동작 원리**:
1. SPI0 버스 활성화
2. MCP2518FD 칩을 SPI0.0에 등록
3. 40MHz 외부 오실레이터 정의
4. GPIO 25를 인터럽트 핀으로 설정

**결과**:
- 커널이 `mcp251xfd` 드라이버 로드
- `can0` 네트워크 인터페이스 생성

#### 6.2.2 rpi-config_%.bbappend

**파일**: `meta-custom/meta-env/recipes-bsp/bootfiles/rpi-config_%.bbappend`

```bash
ENABLE_SPI_BUS = "1"
ENABLE_I2C = "1"
```

**SPI/I2C 활성화**:
- Raspberry Pi 기본값: SPI/I2C 비활성
- 활성화하면 `/dev/spidev0.0`, `/dev/i2c-1` 생성

**config.txt 변환**:
```ini
dtparam=spi=on
dtparam=i2c_arm=on
```

```bash
RPI_KERNEL_DEVICETREE_OVERLAYS:append = " overlays/seeed-can-fd-hat-v2.dtbo"
```

**오버레이 배포**:
- 커널 빌드 시 `.dtbo` 파일 생성
- 부트 파티션의 `/boot/overlays/`에 복사

```bash
GPU_MEM = "128"
```

**GPU 메모리 할당**:
- Raspberry Pi는 CPU/GPU가 DRAM 공유
- 기본값: 64MB (4K 비디오에는 부족)
- 128MB: 듀얼 1080p 디스플레이에 적합

**메모리 분할**:
```
총 4GB RAM
├── GPU: 128MB (Wayland compositor, Qt rendering)
└── CPU: 3872MB (Linux, 애플리케이션)
```

```bash
ENABLE_UART = "1"
```

**UART 활성화**:
- GPIO 14/15를 시리얼 콘솔로 사용
- 디버깅용 (부팅 로그 확인)
- Plymouth 부팅 화면도 UART 지원

```bash
VC4DTBO = "vc4-kms-v3d,noaudio"
```

**VC4 (VideoCore 4) 드라이버**:
- `vc4-kms-v3d`: KMS (Kernel Mode Setting) 활성화
  - 커널이 디스플레이 직접 제어
  - Wayland/X11과 호환

- `noaudio`: HDMI 오디오 비활성화
  - PulseAudio가 오디오 라우팅 담당
  - 중복 방지

```bash
RPI_EXTRA_CONFIG:append = "\
\ndtoverlay=seeed-can-fd-hat-v2\
\nhdmi_drive:0=2\
\nhdmi_drive:1=2\
...
```

**HDMI 설정 상세**:

| 설정 | 값 | 의미 |
|------|-----|------|
| `hdmi_drive:0=2` | 2 | HDMI-0: 일반 DVI (오디오 없음) |
| `hdmi_drive:1=2` | 2 | HDMI-1: 일반 DVI |
| `hdmi_force_hotplug:0=1` | 1 | 디스플레이 없어도 HDMI-0 활성화 |
| `hdmi_force_hotplug:1=1` | 1 | 디스플레이 없어도 HDMI-1 활성화 |
| `hdmi_group:0=2` | 2 | DMT 모드 (PC 모니터) |
| `hdmi_group:1=2` | 2 | DMT 모드 |
| `hdmi_mode:0=87` | 87 | 커스텀 해상도 사용 |
| `hdmi_mode:1=87` | 87 | 커스텀 해상도 사용 |
| `hdmi_cvt:0=1024 600 60 6 0 0 0` | - | 1024x600 60Hz (7인치 디스플레이) |
| `hdmi_cvt:1=1024 600 60 6 0 0 0` | - | 1024x600 60Hz |

**CVT 파라미터**: `width height refresh aspect margins interlace reduced_blanking`
- `1024 600 60`: 해상도 및 주사율
- `6`: 16:9 화면비 (근사값)
- `0 0 0`: 마진, 인터레이스, 리듀스드 블랭킹 없음

```bash
\nconfig_hdmi_boost:0=2\
\nconfig_hdmi_boost:1=2\
```

**HDMI 신호 증폭**:
- 범위: 0-11 (기본값: 5)
- 2: 약간 감소 (짧은 케이블용)
- 긴 HDMI 케이블 사용 시 7-9로 증가

```bash
\nmax_framebuffers=2\
```

**프레임버퍼 개수**:
- 기본값: 1 (싱글 디스플레이)
- 2: 듀얼 디스플레이 지원
- Wayland에서 `/dev/fb0`, `/dev/fb1` 생성

```bash
\ndisable_splash=1\
```

**펌웨어 스플래시 비활성화**:
- RPi 로고 표시 안 함
- Plymouth가 부팅 화면 담당

---

## 7. 시스템 통합 및 부팅 프로세스

### 7.1 부팅 시퀀스 상세

```
┌────────────────────────────────────────────────────────┐
│          Raspberry Pi 4 부팅 프로세스                    │
└────────────────────────────────────────────────────────┘

1. GPU 부팅 (VideoCore)
   ├─ bootcode.bin (ROM에 내장, RPi4)
   ├─ start4.elf 로드 (GPU 펌웨어)
   └─ config.txt 파싱
      ↓
2. CPU 초기화
   ├─ CPU 클록 설정 (1.5GHz)
   ├─ RAM 초기화 (GPU/CPU 분할)
   └─ 디바이스 트리 로드
      ↓
3. 커널 부팅 (Linux)
   ├─ Image (ARM64 커널) 로드
   ├─ bcm2711-rpi-4-b.dtb 적용
   ├─ overlays/*.dtbo 병합 (CAN HAT)
   └─ cmdline.txt (커널 파라미터)
      ↓
4. initramfs (선택사항, 이 프로젝트는 미사용)
      ↓
5. rootfs 마운트
   ├─ /dev/mmcblk0p2 → / (ext4)
   └─ /dev/mmcblk0p1 → /boot (vfat)
      ↓
6. systemd 시작 (PID 1)
   ├─ sysinit.target
   │  ├─ systemd-modules-load.service (커널 모듈)
   │  ├─ systemd-sysctl.service (커널 파라미터)
   │  └─ systemd-tmpfiles-setup.service (임시 파일)
   ↓
   ├─ basic.target
   │  ├─ 네트워크 초기화
   │  ├─ D-Bus 시작
   │  └─ udev (디바이스 관리)
   ↓
   ├─ multi-user.target
   │  ├─ can0.service (CAN 인터페이스)
   │  ├─ can1.service
   │  ├─ pulseaudio.service (오디오 서버)
   │  ├─ bluetooth.service (BlueZ)
   │  ├─ connman.service (네트워크 관리)
   │  └─ piracer-controller.service
   ↓
   └─ graphical.target
      ├─ weston.service (Wayland compositor)
      │  ├─ 듀얼 디스플레이 초기화
      │  └─ Wayland 소켓 생성
      ↓
      ├─ headunit.service
      │  ├─ After=weston.service
      │  ├─ Qt 애플리케이션 시작
      │  └─ HDMI-0 (1024x600) 출력
      ↓
      └─ instrument-cluster.service
         ├─ After=weston.service, piracer-controller.service
         ├─ Qt 계기판 시작
         └─ HDMI-1 (1024x600) 출력
```

### 7.2 systemd 서비스 의존성 그래프

```
graphical.target
    │
    ├─[Requires]─► weston.service
    │                  │
    │                  ├─[After]─► basic.target
    │                  │               │
    │                  │               └─► dbus.service
    │                  │
    │                  └─[BindsTo]─► dev-tty7.device
    │
    ├─[After]─► headunit.service
    │               │
    │               ├─[Requires]─► weston.service
    │               └─[Wants]─► rfkill-unblock.service
    │
    └─[After]─► instrument-cluster.service
                    │
                    ├─[Requires]─► weston.service
                    └─[After]─► piracer-controller.service
                                     │
                                     └─[After]─► can1.service
```

**의존성 타입 설명**:

| 타입 | 동작 | 예시 |
|------|------|------|
| `Requires` | 필수, 실패 시 자신도 중단 | headunit → weston |
| `Wants` | 선택, 실패해도 계속 진행 | headunit → rfkill-unblock |
| `After` | 순서만 지정, 의존성 없음 | headunit after weston |
| `BindsTo` | 타겟 중단 시 자신도 중단 | weston → tty7 |

### 7.3 Wayland 디스플레이 구성

```
┌────────────────────────────────────────────────────────┐
│               Wayland 스택 구조                          │
└────────────────────────────────────────────────────────┘

Hardware
    │
    ├─ HDMI-0 (1024x600)
    │  ↓ KMS (Kernel Mode Setting)
    │  vc4-kms-v3d 드라이버
    │
    └─ HDMI-1 (1024x600)
       ↓ KMS
       vc4-kms-v3d 드라이버

                ↕

Weston (Compositor)
    │
    ├─ Output 0: card0-HDMI-A-1 (HeadUnit 화면)
    │  ├─ wl_output 인터페이스
    │  └─ Wayland 소켓: /run/wayland-0
    │
    └─ Output 1: card0-HDMI-A-2 (Cluster 화면)
       ├─ wl_output 인터페이스
       └─ Wayland 소켓: /run/wayland-0 (공유)

                ↕

Qt Applications
    │
    ├─ HeadUnitApp
    │  ├─ QT_QPA_PLATFORM=wayland
    │  ├─ WAYLAND_DISPLAY=/run/wayland-0
    │  └─ 자동으로 Output 0에 표시
    │
    └─ appIC (Instrument Cluster)
       ├─ QT_QPA_PLATFORM=wayland
       ├─ WAYLAND_DISPLAY=/run/wayland-0
       └─ 자동으로 Output 1에 표시
```

**Wayland 출력 선택 로직**:
1. 애플리케이션이 Weston에 연결
2. Weston이 사용 가능한 출력 목록 전송
3. Qt가 첫 번째 사용 가능한 출력 선택
4. 명시적 선택: `--output HDMI-A-2` 플래그

### 7.4 CAN 통신 아키텍처

```
┌────────────────────────────────────────────────────────┐
│              CAN 버스 통합 구조                          │
└────────────────────────────────────────────────────────┘

Physical Layer
    │
    ├─ MCP2518FD (CAN-FD 컨트롤러)
    │  ├─ SPI0.0 인터페이스
    │  ├─ 40MHz 외부 크리스탈
    │  └─ GPIO 25 (인터럽트)
    │
    └─ CAN 트랜시버 (TJA1051 등)
       ├─ CANH/CANL 버스
       └─ 120Ω 종단 저항

                ↕

Linux Kernel
    │
    ├─ mcp251xfd 드라이버
    │  ├─ SPI 통신
    │  ├─ 인터럽트 처리
    │  └─ SocketCAN 인터페이스 제공
    │
    └─ SocketCAN 서브시스템
       ├─ can0: 500kbps (메인 버스)
       └─ can1: 500kbps (보조 버스)

                ↕

User Space
    │
    ├─ can-utils (디버깅)
    │  ├─ candump can0
    │  ├─ cansend can0 123#DEADBEEF
    │  └─ cangen can0
    │
    └─ Qt Applications
       ├─ QCanBus (Qt Serial Bus)
       ├─ QCanBusDevice::createDevice("socketcan", "can0")
       └─ 메시지 송수신
```

**CAN 메시지 흐름**:

```
Instrument Cluster (송신)
    ↓ QCanBusDevice::writeFrame()
    ↓ ioctl(SIOCGIFINDEX) → can1
    ↓ write() 시스템 콜
    ↓ SocketCAN 레이어
    ↓ mcp251xfd 드라이버
    ↓ SPI 전송
    ↓ MCP2518FD 칩
    ↓ CAN 트랜시버
    ↓ CANH/CANL 버스
         ↓
    ↓ PiRacer Controller 수신
```

---

## 8. 빌드 프로세스 단계별 설명

### 8.1 환경 초기화

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des
```

**oe-init-build-env 스크립트가 하는 일**:

1. **환경 변수 설정**:
   ```bash
   export BUILDDIR=/home/seame/DES_Head-Unit/yocto-workspace/build-des
   export PATH="$PATH:/home/.../poky/scripts:/home/.../bitbake/bin"
   ```

2. **빌드 디렉토리 생성**:
   - `build-des/conf/` 디렉토리 생성
   - 템플릿에서 `local.conf`, `bblayers.conf` 복사

3. **BitBake 경로 추가**:
   - `bitbake` 명령을 셸에서 사용 가능

4. **작업 디렉토리 변경**:
   - `cd build-des`

### 8.2 BitBake 파싱 단계

```bash
bitbake des-image
```

**1단계: 레이어 파싱**
```
Parsing recipes: 100% |███████████████████| Time: 0:02:34
```

**동작**:
- 모든 `.bb`, `.bbappend`, `.conf` 파일 읽기
- Python/Shell 함수 파싱
- 변수 확장 (inheritance 처리)
- 레시피 간 의존성 그래프 생성

**출력 예시**:
```
NOTE: Resolving any missing task queue dependencies
NOTE: Preparing RunQueue
NOTE: Executing Tasks
```

### 8.3 태스크 실행 순서

**단일 레시피의 태스크 체인**:

```
do_fetch
    ↓ (소스 다운로드)
do_unpack
    ↓ (압축 해제)
do_patch
    ↓ (패치 적용)
do_configure
    ↓ (./configure, cmake)
do_compile
    ↓ (make, ninja)
do_install
    ↓ (make install → ${D})
do_package
    ↓ (RPM 생성)
do_package_write_rpm
    ↓ (RPM 파일 저장)
do_populate_sysroot
    ↓ (sysroot에 헤더/라이브러리 복사)
```

**병렬 실행**:
- `qtbase`와 `pulseaudio`는 의존성이 없으므로 동시 빌드
- `headunit`은 `qtbase` 완료 후 시작

### 8.4 크로스 컴파일 환경

```
┌────────────────────────────────────────────────────────┐
│            크로스 컴파일 도구 체인                        │
└────────────────────────────────────────────────────────┘

Host Machine (x86_64)
    │
    ├─ Build System
    │  ├─ BitBake (Python)
    │  ├─ gcc (x86_64 네이티브)
    │  └─ pkg-config
    │
    └─ Target Sysroot
       ├─ aarch64-oe-linux-gcc (크로스 컴파일러)
       │  ├─ --sysroot=tmp-glibc/sysroots-components/raspberrypi4_64
       │  └─ -march=armv8-a+crc+crypto
       │
       └─ Libraries
          ├─ libQt6Core.so (ARM64)
          ├─ glibc (ARM64)
          └─ 헤더 파일 (/usr/include)
```

**컴파일 명령 예시**:
```bash
aarch64-oe-linux-g++ \
  --sysroot=/path/to/sysroot \
  -march=armv8-a+crc+crypto \
  -O2 -pipe \
  -I/path/to/sysroot/usr/include/qt6 \
  -L/path/to/sysroot/usr/lib \
  -lQt6Core \
  -o HeadUnitApp main.cpp
```

### 8.5 rootfs 조립

**do_rootfs 태스크**:

```
1. RPM 데이터베이스 초기화
   ↓
2. IMAGE_INSTALL 패키지 설치
   ├─ rpm -ivh --root=${IMAGE_ROOTFS} qtbase-*.rpm
   ├─ rpm -ivh --root=${IMAGE_ROOTFS} headunit-*.rpm
   └─ ...
   ↓
3. 패키지 의존성 해결
   ├─ RDEPENDS 체인 추적
   └─ 누락된 패키지 자동 설치
   ↓
4. 후처리 스크립트 실행
   ├─ add_users_to_groups
   ├─ enable_pulseaudio_service
   └─ 기타 ROOTFS_POSTPROCESS_COMMAND
   ↓
5. /etc/fstab 생성
   ↓
6. systemd 기본 타겟 설정
   ├─ ln -s graphical.target default.target
   └─ systemctl preset-all
   ↓
7. 임시 파일 정리
   └─ rm -rf /tmp/* /var/tmp/*
```

### 8.6 이미지 생성

**do_image_wic 태스크**:

```
WIC (Wic Image Creator) 동작:
    ↓
1. 파티션 레이아웃 정의 (.wks 파일)
   ┌─────────────────────────────────────┐
   │ Partition 1: /boot (FAT32, 96MB)   │
   │   ├─ bootcode.bin                  │
   │   ├─ start4.elf                    │
   │   ├─ config.txt                    │
   │   ├─ Image (커널)                  │
   │   └─ overlays/*.dtbo               │
   ├─────────────────────────────────────┤
   │ Partition 2: / (ext4, 나머지)       │
   │   ├─ /bin, /sbin → /usr/bin       │
   │   ├─ /lib → /usr/lib               │
   │   ├─ /etc (설정 파일)              │
   │   ├─ /usr (프로그램)               │
   │   └─ /var (로그, 캐시)             │
   └─────────────────────────────────────┘
    ↓
2. 파티션 이미지 생성
   ├─ mkfs.vfat -n BOOT boot.img
   ├─ mkfs.ext4 -L root rootfs.img
   └─ e2fsck -f rootfs.img
    ↓
3. 파일 복사
   ├─ mcopy boot_files → boot.img
   └─ dd if=rootfs.tar of=rootfs.img
    ↓
4. 파티션 결합
   └─ dd if=boot.img of=final.img bs=1M
   └─ dd if=rootfs.img of=final.img bs=1M seek=96
    ↓
5. 압축 (선택)
   └─ bzip2 final.img → des-image.wic.bz2
```

### 8.7 최종 산출물

```bash
build-des/tmp-glibc/deploy/images/raspberrypi4-64/
├─ des-image-raspberrypi4-64-20231209120000.rootfs.wic.bz2
│  (압축된 WIC 이미지, 약 500MB)
│
├─ des-image-raspberrypi4-64-20231209120000.rootfs.rpi-sdimg
│  (원시 SD 카드 이미지, 약 2GB)
│
├─ des-image-raspberrypi4-64.manifest
│  (설치된 모든 패키지 목록)
│
├─ Image
│  (Linux 커널 이미지)
│
├─ bcm2711-rpi-4-b.dtb
│  (디바이스 트리)
│
└─ modules-*.tgz
   (커널 모듈)
```

**이미지 플래싱**:

```bash
# 방법 1: dd (Linux/Mac)
bunzip2 -c des-image-*.wic.bz2 | sudo dd of=/dev/sdX bs=4M status=progress

# 방법 2: bmaptool (더 빠름)
bmaptool copy des-image-*.wic.bz2 /dev/sdX

# 방법 3: balenaEtcher (GUI)
# .rpi-sdimg 파일 사용
```

---

## 9. 요약 및 학습 포인트

### 9.1 핵심 개념 정리

| 개념 | 설명 | 이 프로젝트에서의 역할 |
|------|------|----------------------|
| **레이어** | 레시피의 모듈 단위 | meta-env, meta-app, meta-piracer로 분리 |
| **레시피** | 패키지 빌드 방법 | headunit.bb, des-image.bb 등 |
| **클래스** | 재사용 가능한 로직 | qt6-cmake, systemd, core-image |
| **bbappend** | 기존 레시피 확장 | linux-raspberrypi, weston-init |
| **DEPENDS** | 빌드 타임 의존성 | 헤더 파일, 라이브러리 |
| **RDEPENDS** | 런타임 의존성 | 공유 라이브러리, 실행 파일 |
| **태스크** | 빌드 단계 | do_fetch, do_compile, do_install |
| **${D}** | 가짜 루트 | 실제 / 대신 사용 |
| **sysroot** | 크로스 컴파일 환경 | ARM64 라이브러리/헤더 |

### 9.2 왜 Yocto를 사용하는가?

**장점**:
1. **재현성**: 같은 설정으로 동일한 이미지 생성
2. **맞춤화**: 불필요한 패키지 제거 (크기 최소화)
3. **보안**: CVE 패치 자동 추적
4. **크로스 플랫폼**: x86, ARM, MIPS 등 지원
5. **엔터프라이즈 지원**: 자동차, 의료기기 인증

**단점**:
1. **학습 곡선**: 초기 설정 복잡
2. **빌드 시간**: 첫 빌드 수 시간 소요
3. **디스크 사용**: 50-100GB 필요
4. **디버깅 어려움**: 오류 추적 복잡

### 9.3 이 프로젝트의 독특한 점

1. **듀얼 디스플레이**: Wayland로 두 화면 동시 구동
2. **Qt 6 Wayland**: 최신 Qt와 경량 디스플레이 서버 조합
3. **CAN-FD 통합**: MCP2518FD를 디바이스 트리로 통합
4. **systemd 완전 활용**: 서비스 의존성 정교하게 관리
5. **모듈식 레이어 구조**: 환경/앱/하드웨어 분리

### 9.4 추가 학습 자료

- **Yocto 공식 문서**: https://docs.yoctoproject.org/
- **BitBake 매뉴얼**: https://docs.yoctoproject.org/bitbake/
- **meta-raspberrypi**: https://github.com/agherzan/meta-raspberrypi
- **Qt 문서**: https://doc.qt.io/qt-6/
- **SocketCAN**: https://www.kernel.org/doc/Documentation/networking/can.txt

---

## 10. 문제 해결 가이드

### 10.1 빌드 오류

**오류**: `ERROR: Nothing PROVIDES 'qtbase'`
- **원인**: meta-qt6 레이어 누락
- **해결**: `bblayers.conf`에 레이어 추가

**오류**: `do_compile failed` (컴파일 오류)
- **원인**: 소스 코드 문제, 의존성 누락
- **해결**:
  ```bash
  bitbake -c compile -f headunit  # 강제 재컴파일
  cat tmp-glibc/work/.../temp/log.do_compile  # 로그 확인
  ```

### 10.2 런타임 문제

**문제**: HeadUnit이 시작되지 않음
- **확인**:
  ```bash
  ssh root@<rpi-ip>
  systemctl status headunit
  journalctl -u headunit -f
  ```

**문제**: Wayland 오류 (`Could not connect to wayland server`)
- **확인**:
  ```bash
  systemctl status weston
  ls -la /run/wayland-0  # 소켓 존재 확인
  ```

**문제**: CAN 인터페이스 없음
- **확인**:
  ```bash
  ip link show can0
  dmesg | grep -i can
  lsmod | grep mcp251xfd
  ```

---

**이 문서는 DES Head-Unit 프로젝트의 모든 기술적 세부사항을 다룹니다. 각 설정 파일, 코드 라인, 디자인 결정의 이유를 설명하여 Yocto 초보자도 프로젝트를 완전히 이해할 수 있도록 작성되었습니다.**
