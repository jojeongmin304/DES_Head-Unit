# Bluetooth Setup Issues / 블루투스 설정 문제

## 🇰🇷 한국어

### 주요 문제점

#### 1. 블루투스 에이전트 자동 신뢰 처리 문제
- **문제**: BlueZ 에이전트가 페어링 요청(`RequestConfirmation`, `RequestAuthorization`)에 응답할 때, Qt D-Bus의 자동 응답 메커니즘이 제대로 작동하지 않아 페어링이 타임아웃되거나 실패함
- **원인**: D-Bus 메서드가 void를 반환할 때 Qt가 자동으로 `method_return` 메시지를 보내야 하는데, 에이전트 등록 및 응답 타이밍 문제로 BlueZ가 응답을 받지 못함
- **해결**: 에이전트 메서드에서 명시적으로 함수를 정상 반환하도록 구현하여 Qt D-Bus가 자동으로 성공 응답을 보내도록 함. `RequestConfirmation()`과 같은 메서드에서 아무것도 throw하지 않고 정상 반환하면 BlueZ가 승인으로 처리

#### 2. D-Bus 시스템 버스 권한 설정 문제
- **문제**: HeadUnit 애플리케이션이 시스템 버스에서 BlueZ 데몬과 통신하려 할 때 권한 거부(`org.freedesktop.DBus.Error.AccessDenied`) 오류 발생
- **원인**: D-Bus 정책 설정이 없어서 기본적으로 비특권 프로세스가 BlueZ의 민감한 메서드(AgentManager1, Device1, MediaPlayer1 등)를 호출할 수 없음
- **해결**: `/etc/dbus-1/system.d/headunit-bluetooth.conf` 파일 생성하여 다음 권한 명시:
  - `headunit` 사용자에게 BlueZ 통신 권한 부여
  - 에이전트 등록/해제 허용 (`RegisterAgent`, `UnregisterAgent`)
  - 디바이스 제어 허용 (`Connect`, `Disconnect`, `Pair`)
  - 미디어 플레이어 제어 허용 (`Play`, `Pause`, `Next`, `Previous`)
  - Properties 및 ObjectManager 인터페이스 접근 허용
  - `bluealsa` 사용자에게 오디오 프로파일 등록 권한 부여

---

## 🇬🇧 English

### Main Issues

#### 1. Bluetooth Agent Auto-Trust Handling Problem
- **Problem**: When the BlueZ agent responds to pairing requests (`RequestConfirmation`, `RequestAuthorization`), Qt D-Bus's automatic response mechanism doesn't work properly, causing pairing to timeout or fail
- **Cause**: When D-Bus methods return void, Qt should automatically send a `method_return` message, but due to agent registration and response timing issues, BlueZ doesn't receive the response
- **Solution**: Implemented agent methods to explicitly return normally so Qt D-Bus automatically sends a success response. Methods like `RequestConfirmation()` that return without throwing are interpreted as approval by BlueZ

#### 2. D-Bus System Bus Permission Configuration Problem
- **Problem**: HeadUnit application encounters permission denied errors (`org.freedesktop.DBus.Error.AccessDenied`) when attempting to communicate with the BlueZ daemon on the system bus
- **Cause**: Without D-Bus policy configuration, unprivileged processes cannot call BlueZ's sensitive methods (AgentManager1, Device1, MediaPlayer1, etc.) by default
- **Solution**: Created `/etc/dbus-1/system.d/headunit-bluetooth.conf` file with explicit permissions:
  - Grant `headunit` user permission to communicate with BlueZ
  - Allow agent registration/unregistration (`RegisterAgent`, `UnregisterAgent`)
  - Allow device control (`Connect`, `Disconnect`, `Pair`)
  - Allow media player control (`Play`, `Pause`, `Next`, `Previous`)
  - Allow access to Properties and ObjectManager interfaces
  - Grant `bluealsa` user permission to register audio profiles

---

## 🇰🇷 한국어

### 주요 문제점

#### 3. 듀얼 모니터 (EGLFS → Wayland 전환) 문제
- **문제**: EGLFS 백엔드 사용 시 두 개의 모니터(HDMI-A-1, HDMI-A-2)에 각각 다른 Qt 애플리케이션(HeadUnit, Instrument Cluster)을 동시에 띄울 수 없었음
- **원인**:
  - EGLFS는 single-display 전용 백엔드로 설계되어 한 번에 하나의 프레임버퍼만 직접 제어
  - Qt 애플리케이션 하나당 하나의 디스플레이만 점유 가능
  - 멀티 디스플레이 지원이 제한적이고 복잡한 설정 필요
  - 각 애플리케이션이 독립적으로 GPU를 점유하려 해서 충돌 발생
- **해결**: Wayland compositor (Weston) 기반 아키텍처로 전환
  - Weston이 모든 디스플레이를 통합 관리하는 compositor로 작동
  - 각 Qt 애플리케이션은 Wayland 클라이언트로 실행되어 compositor에게 렌더링 요청
  - `QT_QPA_PLATFORM=wayland` 환경변수로 Wayland 백엔드 활성화
  - `QT_WAYLAND_FULLSCREEN_OUTPUT=HDMI-A-2` 환경변수로 특정 디스플레이에 출력 지정
  - HeadUnit은 HDMI-A-1(기본), Instrument Cluster는 HDMI-A-2로 자동 배치

---

## 🇬🇧 English

### Main Issues

#### 3. Dual Monitor (EGLFS → Wayland Migration) Problem
- **Problem**: When using EGLFS backend, couldn't simultaneously display two different Qt applications (HeadUnit, Instrument Cluster) on two monitors (HDMI-A-1, HDMI-A-2)
- **Cause**:
  - EGLFS is designed as a single-display backend that directly controls only one framebuffer at a time
  - One Qt application can only occupy one display
  - Multi-display support is limited and requires complex configuration
  - Conflicts occurred when each application tried to exclusively access the GPU
- **Solution**: Migrated to Wayland compositor (Weston) based architecture
  - Weston acts as a compositor that manages all displays in an integrated manner
  - Each Qt application runs as a Wayland client and requests rendering from the compositor
  - Enabled Wayland backend with `QT_QPA_PLATFORM=wayland` environment variable
  - Specified output display with `QT_WAYLAND_FULLSCREEN_OUTPUT=HDMI-A-2` environment variable
  - HeadUnit automatically assigned to HDMI-A-1 (default), Instrument Cluster to HDMI-A-2

---

## Related Files / 관련 파일

### Bluetooth / 블루투스
- `Head-Unit/src/backend/bluetooth/bluetooth_agent.cpp` - Agent implementation with auto-accept logic
- `yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/headunit-bluetooth.conf` - D-Bus policy configuration
- `Head-Unit/src/backend/bluetooth/bluetooth_manager.cpp` - Agent registration and device management

### Display / 디스플레이
- `yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/headunit.service` - HeadUnit systemd service with Wayland configuration
- `yocto-workspace/meta-custom/meta-app/recipes-des/instrument-cluster/files/instrument-cluster.service` - Instrument Cluster systemd service with HDMI-A-2 output
- `yocto-workspace/meta-custom/meta-env/conf/distro/des.conf` - Distribution-level Wayland configuration
- `yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/` - Weston compositor configuration
