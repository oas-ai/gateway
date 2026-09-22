//! Gateway host의 read-only CAN 처리 경계다.

#![forbid(unsafe_code)]

use oas_can::decode::{DecodeContext, FrameDecoder};
use oas_can::frame::CanFrame;
use oas_car::adapter::ManufacturerAdapter;
use oas_car::vehicle_state::VehicleState;
use prost::Message;

pub mod protobuf;
#[cfg(target_os = "linux")]
pub mod socketcan;

/// DBC decoder와 제조사 adapter를 연결하는 최소 read-only pipeline이다.
#[derive(Debug)]
pub struct Gateway<D, A> {
    decoder: D,
    adapter: A,
}

pub type GatewayResult<T, D, A> = Result<T, GatewayError<D, A>>;

impl<D, A> Gateway<D, A> {
    pub fn new(decoder: D, adapter: A) -> Self {
        Self { decoder, adapter }
    }

    pub fn adapter(&self) -> &A {
        &self.adapter
    }
}

impl<D, A> Gateway<D, A>
where
    D: FrameDecoder,
    A: ManufacturerAdapter,
{
    /// 하나의 수신 frame을 상태에 반영하고, 갱신된 snapshot을 반환한다.
    pub fn ingest(
        &mut self,
        frame: &CanFrame,
        context: DecodeContext,
    ) -> GatewayResult<Option<VehicleState>, D::Error, A::Error> {
        let Some(message) = self
            .decoder
            .decode(frame, context)
            .map_err(GatewayError::Decode)?
        else {
            return Ok(None);
        };

        self.adapter.apply(&message).map_err(GatewayError::Adapt)?;
        Ok(Some(self.adapter.vehicle_state().clone()))
    }

    /// 하나의 수신 frame을 protobuf wire-format snapshot으로 반환한다.
    pub fn ingest_protobuf(
        &mut self,
        frame: &CanFrame,
        context: DecodeContext,
    ) -> GatewayResult<Option<Vec<u8>>, D::Error, A::Error> {
        Ok(self
            .ingest(frame, context)?
            .map(|state| protobuf::vehicle_state(&state).encode_to_vec()))
    }
}

/// Gateway pipeline의 decode 또는 adapter 오류다.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GatewayError<D, A> {
    Decode(D),
    Adapt(A),
}
