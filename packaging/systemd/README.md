# systemd deployment

이 패키지는 read-only `oas-gateway-host`와 `ohayess-runtime`을 한 감독 프로세스로 실행한다. Gateway가 종료되면 runtime의 stdin도 종료하고 새 gateway stream에 다시 연결한다. 재시작 간격은 1초에서 시작해 5초를 넘지 않으며, 30초 이상 정상 실행하면 다시 1초로 초기화한다.

대상 차량에서 먼저 `can0`을 SocketCAN interface로 설정하고, `oas` system user와 아래 경로를 준비한다.

```sh
sudo install -d -o root -g root -m 0755 /usr/lib/oas-gateway/bin /etc/oas-gateway
sudo install -m 0755 target/release/oas-gateway-host /usr/lib/oas-gateway/bin/
sudo install -m 0755 /path/to/ohayess-runtime /usr/lib/oas-gateway/bin/
sudo install -m 0755 scripts/run-gateway-runtime.sh /usr/lib/oas-gateway/
sudo install -m 0640 packaging/systemd/runtime.env /etc/oas-gateway/runtime.env
sudo install -m 0644 packaging/systemd/oas-gateway-runtime@.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now oas-gateway-runtime@can0.service
```

`oas` user가 없으면 OS의 system-user 관리 절차로 만들고, `runtime.env`에서 bus·freshness·backoff만 조정한다. 서비스는 `CAP_NET_RAW` 외 권한을 부여하지 않으며 CAN interface가 사라지면 함께 중지된다.

배포 전 Linux에서 `cargo build --release -p oas-gateway-host` 및 recovery E2E를 실행한다. 운영 로그 확인은 `journalctl -u oas-gateway-runtime@can0 -f`를 사용한다.
