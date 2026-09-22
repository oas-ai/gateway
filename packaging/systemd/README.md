# systemd deployment

이 패키지는 read-only `oas-gateway-host`, `ohayess-runtime`, `ohayess-viewer`를 한 감독 프로세스로 실행한다. Gateway snapshot은 runtime과 loopback Viewer에 fan-out되고, Runtime은 정책 결과를 포함한 `HmiState`를 Qt/QML HMI의 `/run/oas-hmi/vehicle-state` FIFO에 전달한다. HMI bridge는 `HmiState` protobuf를 직접 decode한다. 하나가 종료되면 모두 새 stream으로 재연결한다. 재시작 간격은 1초에서 시작해 5초를 넘지 않으며, 30초 이상 정상 실행하면 다시 1초로 초기화한다.

대상 차량에서 먼저 `can0`을 SocketCAN interface로 설정하고, `oas` system user와 아래 경로를 준비한다.

```sh
sudo install -d -o root -g root -m 0755 /usr/lib/oas-gateway/bin /etc/oas-gateway
sudo install -m 0755 target/release/oas-gateway-host /usr/lib/oas-gateway/bin/
sudo install -m 0755 /path/to/ohayess-runtime /usr/lib/oas-gateway/bin/
sudo install -m 0755 /path/to/ohayess-viewer /usr/lib/oas-gateway/bin/
sudo install -d -o root -g root -m 0755 /usr/lib/oas-hmi
sudo install -m 0755 /path/to/ohayess-hmi /usr/lib/oas-hmi/
sudo install -m 0755 scripts/run-gateway-runtime.sh /usr/lib/oas-gateway/
sudo install -m 0640 packaging/systemd/runtime.env /etc/oas-gateway/runtime.env
sudo install -m 0644 packaging/systemd/oas-gateway-runtime@.service /etc/systemd/system/
sudo install -m 0644 packaging/systemd/ohayess-hmi.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ohayess-hmi.service
sudo systemctl enable --now oas-gateway-runtime@can0.service
```

`oas` user가 없으면 OS의 system-user 관리 절차로 만들고, `runtime.env`에서 bus·freshness·backoff·Viewer loopback 주소·HMI FIFO 경로를 조정한다. Viewer는 기본으로 `127.0.0.1:8080`에서만 수신한다. Gateway 서비스는 `CAP_NET_RAW` 외 권한을 부여하지 않으며 CAN interface가 사라지면 함께 중지된다.

배포 전 Linux에서 `cargo build --release -p oas-gateway-host`, `cargo build --release -p ohayess-runtime -p ohayess-viewer`, 그리고 Viewer recovery E2E를 실행한다. 운영 로그 확인은 `journalctl -u oas-gateway-runtime@can0 -f`를 사용한다.

설치·기동 뒤에는 service를 재시작하거나 CAN frame을 보내지 않는 사전점검을 실행한다.

```sh
sudo install -m 0755 scripts/preflight-linux.sh /usr/lib/oas-gateway/
sudo OAS_CAN_BITRATE=500000 /usr/lib/oas-gateway/preflight-linux.sh can0
```

`OAS_CAN_BITRATE`는 대상 CAN bitrate와 일치시킨다. 이 점검은 interface UP/bitrate, systemd의
`NoNewPrivileges`, service 활성 상태, loopback HMI의 `rawDiagnostics` 응답만 읽는다.
