# Changelog

## Unreleased

- Add a read-only Rust host pipeline with Genesis G80 and simulator-fixture integration tests.
- Add a Linux SocketCAN receiver for classic CAN and CAN FD data frames.
- Add canonical VehicleState to `oas-sdk` protobuf output.
- Add an opt-in `vcan0` receive smoke test and run it in Linux CI.
- Add the blocking Linux host daemon with kernel receive timestamps and length-prefixed protobuf output.
- Add a Linux vcan end-to-end test from a CAN frame through the gateway protobuf stream to the ohayessOS runtime.
- Expand the vcan end-to-end scenario to verify accumulated speed, acceleration, steering, and braking state.

## [0.1.0] - 2026-09-21

- C11 firmware 경계와 CMake 기반 CI를 추가했습니다.
