# gateway

OAS Gateway의 Hardware·Firmware·Host daemon 경계를 관리합니다.

- `firmware/`: MCU 및 CAN controller 연동용 C11 firmware
- `host/`: Host-side read-only Rust pipeline. DBC decoder와 manufacturer adapter를 연결하고 Linux에서는 SocketCAN 수신을 지원한다.

Firmware는 Application에 Raw CAN TX 권한을 제공하지 않습니다.

`host`는 canonical `VehicleState` snapshot과 `oas-sdk` 기반 protobuf wire-format을 생성합니다. SDK generated source는 schema repository의 build에서 관리하며 이 저장소는 생성물을 소유하지 않습니다.
