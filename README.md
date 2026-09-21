# gateway

OAS Gateway의 Hardware·Firmware·Host daemon 경계를 관리합니다.

- `firmware/`: MCU 및 CAN controller 연동용 C11 firmware
- `host/`: Host-side service용 Rust workspace (도입 예정)

Firmware는 Application에 Raw CAN TX 권한을 제공하지 않습니다.
