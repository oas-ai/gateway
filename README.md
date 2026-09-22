# gateway

OAS Gateway의 Hardware·Firmware·Host daemon 경계를 관리합니다.

- `firmware/`: MCU 및 CAN controller 연동용 C11 firmware
- `host/`: Host-side read-only Rust pipeline. DBC decoder와 manufacturer adapter를 연결하고 Linux에서는 SocketCAN 수신을 지원한다.

Firmware는 Application에 Raw CAN TX 권한을 제공하지 않습니다.

`host`는 canonical `VehicleState` snapshot과 `oas-sdk` 기반 protobuf wire-format을 생성합니다. SDK generated source는 schema repository의 build에서 관리하며 이 저장소는 생성물을 소유하지 않습니다.

Linux host에서는 `cargo run -p oas-gateway-host -- can0 0`으로 daemon을 실행합니다. 첫 인자는 SocketCAN interface, 두 번째 인자는 bus 번호이며 생략하면 각각 `can0`, `0`입니다. stdout은 각 protobuf snapshot 앞에 4-byte big-endian 길이를 붙인 binary stream입니다.

Linux SocketCAN smoke test는 `vcan0`을 생성한 뒤 `cargo test --test socketcan_vcan -- --ignored`로 실행합니다.

전체 E2E는 `can-utils`와 `vcan0`을 준비하고 gateway 및 ohayessOS runtime을 빌드한 뒤 `./scripts/e2e-vcan.sh <ohayess-runtime 경로>`로 실행합니다. 테스트는 Genesis G80 프레임과 CGW1 저빔 신호를 보내고 runtime의 최신 protobuf `VehicleState`에 속도 약 22.22 m/s, 종가속도 1.25 m/s², 조향각 π/2 rad, 브레이크 입력, `night_mode`가 함께 누적되는지 확인합니다.

`scripts/run-gateway-runtime.sh`는 gateway 종료 뒤 runtime을 새 stdout stream에 자동 재연결합니다. `OAS_HMI_BIN`을 설정하면 같은 snapshot을 runtime과 loopback HMI에 fan-out합니다. restart backoff는 1초에서 시작해 최대 5초이며, `./scripts/e2e-recovery-vcan.sh <ohayess-runtime 경로>`와 `./scripts/e2e-hmi-recovery-vcan.sh <ohayess-runtime 경로> <ohayess-hmi 경로>`가 gateway 종료·재시작 뒤 상태 수신, HMI route·tab 렌더링, 주행 중 미디어 잠금 및 `nightMode` 기반 다크 전환을 검증합니다.

실차 Linux 배포용 systemd template과 설치 절차는 [packaging/systemd/](packaging/systemd/README.md)에 있습니다. 이 서비스는 `oas-gateway-runtime@can0`처럼 CAN interface별로 실행하며 read-only SocketCAN 수신에 필요한 `CAP_NET_RAW`만 부여합니다.
