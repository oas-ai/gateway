#![cfg(target_os = "linux")]

use oas_can::frame::CanId;
use oas_gateway_host::socketcan::SocketCanReceiver;
use socketcan::{CanFrame, CanSocket, EmbeddedFrame as _, Socket as _};

#[test]
#[ignore = "requires a configured vcan0 interface"]
fn receives_a_classic_frame_from_vcan() {
    let receiver = SocketCanReceiver::open("vcan0", 7).unwrap();
    let sender = CanSocket::open("vcan0").unwrap();
    let frame = CanFrame::new(socketcan::StandardId::new(0x123).unwrap(), &[0xde, 0xad]).unwrap();

    sender.write_frame(&frame).unwrap();
    let (received, context) = receiver.receive().unwrap().unwrap();

    assert_eq!(received.id, CanId::standard(0x123).unwrap());
    assert_eq!(received.data, [0xde, 0xad]);
    assert!(!received.is_fd);
    assert!(context.timestamp_ns.is_some());
    assert_eq!(context.bus, 7);
}
