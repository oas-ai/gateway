#!/usr/bin/env bash
# Synthetic DBC fixture only. It is not a vehicle capture or a claim about a VIN/trim.

send_palisade_2020_frames() {
  cansend vcan0 4F1#00A00000
  cansend vcan0 2B0#8403000000
  cansend vcan0 394#000000007C440000
  cansend vcan0 541#0055408C40000000
  cansend vcan0 521#3900000000000000
  cansend vcan0 042#0C00100000000000
  cansend vcan0 367#0000000000000000
  cansend vcan0 386#0020001000080004
  cansend vcan0 389#0000000001000000
}
