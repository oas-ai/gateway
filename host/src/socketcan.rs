//! Linux SocketCAN 수신 adapter다.

use std::io;
use std::time::UNIX_EPOCH;

use oas_can::decode::DecodeContext;
use oas_can::frame::{CanFrame, CanFrameError, CanId};
use socketcan::{CanAnyFrame, CanFdSocket, EmbeddedFrame as _, Socket as _, SocketOptions as _};

/// SocketCAN 수신 frame을 OAS frame으로 변환할 수 없는 오류다.
#[derive(Debug)]
pub enum SocketCanError {
    Io(io::Error),
    Frame(CanFrameError),
}

impl From<io::Error> for SocketCanError {
    fn from(error: io::Error) -> Self {
        Self::Io(error)
    }
}

impl From<CanFrameError> for SocketCanError {
    fn from(error: CanFrameError) -> Self {
        Self::Frame(error)
    }
}

/// Classic CAN과 CAN FD를 모두 읽는 SocketCAN receiver다.
#[derive(Debug)]
pub struct SocketCanReceiver {
    socket: CanFdSocket,
    bus: u8,
}

impl SocketCanReceiver {
    pub fn open(interface: &str, bus: u8) -> Result<Self, SocketCanError> {
        let socket = CanFdSocket::open(interface)?;
        socket.set_recv_timestamp(true)?;
        Ok(Self { socket, bus })
    }

    /// 하나의 data frame을 읽는다. remote/error frame은 상태 pipeline에 전달하지 않는다.
    pub fn receive(&self) -> Result<Option<(CanFrame, DecodeContext)>, SocketCanError> {
        let (frame, timestamp) = self.socket.read_frame_with_timestamp()?;
        let (id, data, is_fd) = match frame {
            CanAnyFrame::Normal(frame) => (frame.id(), frame.data().to_vec(), false),
            CanAnyFrame::Fd(frame) => (frame.id(), frame.data().to_vec(), true),
            CanAnyFrame::Remote(_) | CanAnyFrame::Error(_) => return Ok(None),
        };
        let id = match id {
            socketcan::Id::Standard(id) => {
                CanId::standard(id.as_raw()).expect("validated by SocketCAN")
            }
            socketcan::Id::Extended(id) => {
                CanId::extended(id.as_raw()).expect("validated by SocketCAN")
            }
        };

        Ok(Some((
            CanFrame::new(id, data, is_fd)?,
            DecodeContext {
                timestamp_ns: timestamp
                    .duration_since(UNIX_EPOCH)
                    .ok()
                    .and_then(|duration| u64::try_from(duration.as_nanos()).ok()),
                bus: self.bus,
            },
        )))
    }
}
