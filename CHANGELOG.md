# Changelog

## Unreleased

- Verify Palisade synthetic vCAN frames through Runtime into a rendered Qt HMI screenshot in CI.

- Add a read-only Linux deployment preflight for SocketCAN, systemd, and HMI diagnostics.
- Add a shared synthetic Palisade DBC fixture and assert raw diagnostics in the vCAN-to-HMI E2E path.
- Forward DBC-trusted Palisade raw body, door, seatbelt, and climate diagnostics to the SDK state stream.
- Add a read-only Rust host pipeline with Hyundai Palisade 2020 and simulator-fixture integration tests.
- Add a Linux SocketCAN receiver for classic CAN and CAN FD data frames.
- Add canonical VehicleState to `oas-sdk` protobuf output.
- Add an opt-in `vcan0` receive smoke test and run it in Linux CI.
- Add the blocking Linux host daemon with kernel receive timestamps and length-prefixed protobuf output.
- Add a Linux vcan end-to-end test from a CAN frame through the gateway protobuf stream to the ohayessOS runtime.
- Expand the vcan end-to-end scenario to verify accumulated speed, acceleration, steering, and braking state.
- Add bounded gateway restart recovery with a vcan end-to-end recovery test.
- Add a hardened systemd template package for real-vehicle Linux deployment.

## [0.1.0] - 2026-09-21

- C11 firmware 경계와 CMake 기반 CI를 추가했습니다.
