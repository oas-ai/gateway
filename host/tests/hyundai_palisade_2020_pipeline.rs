use oas_can::decode::DecodeContext;
use oas_can::frame::{CanFrame, CanId};
use oas_can::hyundai_palisade_2020::HyundaiPalisade2020Decoder;
use oas_car::hyundai_palisade_2020::HyundaiPalisade2020Adapter;
use oas_car::vehicle_state::GearPosition;
use oas_gateway_host::Gateway;
use oas_sdk::vehicle::v1::VehicleState;
use prost::Message;

fn frame(id: u16, data: Vec<u8>) -> CanFrame {
    CanFrame::new(CanId::standard(id).unwrap(), data, false).unwrap()
}

#[test]
fn gateway_converts_palisade_frames_to_canonical_state() {
    let mut gateway = Gateway::new(
        HyundaiPalisade2020Decoder,
        HyundaiPalisade2020Adapter::default(),
    );
    let context = DecodeContext {
        timestamp_ns: Some(1_000),
        bus: 0,
    };

    let state = gateway
        .ingest(&frame(1265, vec![0, 160, 0, 0]), context)
        .unwrap()
        .unwrap();
    assert!((state.vehicle_speed_mps.unwrap() - 80.0 / 3.6).abs() < 0.000_01);

    let state = gateway
        .ingest(&frame(688, vec![132, 3, 0, 0, 0]), context)
        .unwrap()
        .unwrap();
    assert!((state.steering.angle_rad.unwrap() - std::f32::consts::FRAC_PI_2).abs() < 0.000_001);

    let state = gateway
        .ingest(&frame(916, vec![0, 0, 0, 0, 124, 68, 0, 0]), context)
        .unwrap()
        .unwrap();
    assert!((state.acceleration_mps2.unwrap() - 1.25).abs() < 0.000_01);
    assert_eq!(state.brake.pressed, Some(true));
    assert!(state.is_fresh_at(1_050, 50));

    let state = gateway
        .ingest(&frame(1345, vec![0, 0, 0, 128, 0, 0, 0, 0]), context)
        .unwrap()
        .unwrap();
    assert_eq!(state.night_mode, Some(true));

    let state = gateway
        .ingest(&frame(871, vec![0, 0, 0, 0, 0, 0, 0, 0]), context)
        .unwrap()
        .unwrap();
    assert_eq!(state.gear.position, GearPosition::Park);

    let state = gateway
        .ingest(&frame(902, vec![0, 32, 0, 16, 0, 8, 0, 4]), context)
        .unwrap()
        .unwrap();
    assert_eq!(state.wheels.len(), 4);
    assert_eq!(state.wheels[0].speed_mps, Some(256.0 / 3.6));

    let state = gateway
        .ingest(&frame(905, vec![0, 0, 0, 0, 1, 0, 0, 0]), context)
        .unwrap()
        .unwrap();
    assert_eq!(state.cruise.enabled, Some(true));
}

#[test]
fn gateway_emits_the_sdk_vehicle_state_wire_contract() {
    let mut gateway = Gateway::new(
        HyundaiPalisade2020Decoder,
        HyundaiPalisade2020Adapter::default(),
    );
    gateway
        .ingest(
            &frame(871, vec![0, 0, 0, 0, 0, 0, 0, 0]),
            DecodeContext {
                timestamp_ns: Some(1_000),
                bus: 0,
            },
        )
        .unwrap();
    gateway
        .ingest(
            &frame(902, vec![0, 32, 0, 16, 0, 8, 0, 4]),
            DecodeContext {
                timestamp_ns: Some(1_000),
                bus: 0,
            },
        )
        .unwrap();
    gateway
        .ingest(
            &frame(905, vec![0, 0, 0, 0, 1, 0, 0, 0]),
            DecodeContext {
                timestamp_ns: Some(1_000),
                bus: 0,
            },
        )
        .unwrap();
    let bytes = gateway
        .ingest_protobuf(
            &frame(1265, vec![0, 160, 0, 0]),
            DecodeContext {
                timestamp_ns: Some(1_000),
                bus: 0,
            },
        )
        .unwrap()
        .unwrap();
    let state = VehicleState::decode(bytes.as_slice()).unwrap();

    assert_eq!(state.timestamp_ns, Some(1_000));
    assert!((state.vehicle_speed_mps.unwrap() - 80.0 / 3.6).abs() < 0.000_01);
    assert_eq!(state.gear.unwrap().position, 1);
    assert_eq!(state.wheels.len(), 4);
    assert_eq!(state.cruise.unwrap().enabled, Some(true));
}
