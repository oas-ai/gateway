use oas_can::decode::{DecodedCanMessage, SignalValue};
use oas_can::fixture::{FixtureDecoder, FixtureMessage};
use oas_can::frame::{CanFrame, CanId};
use oas_car::adapter::ManufacturerAdapter;
use oas_car::vehicle_state::VehicleState;
use oas_gateway_host::Gateway;

#[derive(Default)]
struct SyntheticAdapter {
    state: VehicleState,
}

impl ManufacturerAdapter for SyntheticAdapter {
    type Error = ();

    fn apply(&mut self, message: &DecodedCanMessage) -> Result<(), Self::Error> {
        self.state.timestamp_ns = message.context.timestamp_ns;
        self.state.vehicle_speed_mps = match message.signals.get("speed_mps") {
            Some(SignalValue::Number(speed)) => Some(*speed as f32),
            _ => None,
        };
        self.state.brake.pressed = match message.signals.get("brake_pressed") {
            Some(SignalValue::Boolean(pressed)) => Some(*pressed),
            _ => None,
        };
        Ok(())
    }

    fn vehicle_state(&self) -> &VehicleState {
        &self.state
    }
}

#[test]
fn simulator_fixture_flows_through_the_gateway() {
    let fixture: serde_json::Value = serde_json::from_str(include_str!(
        "../../../simulator/fixtures/synthetic_vehicle_status.json"
    ))
    .unwrap();
    let frame_id = CanId::standard(fixture["frame"]["id"].as_u64().unwrap() as u16).unwrap();
    let frame = CanFrame::new(
        frame_id,
        fixture["frame"]["data"]
            .as_array()
            .unwrap()
            .iter()
            .map(|value| value.as_u64().unwrap() as u8)
            .collect(),
        fixture["frame"]["is_fd"].as_bool().unwrap(),
    )
    .unwrap();
    let mut decoder = FixtureDecoder::default();
    decoder.insert(
        frame_id,
        FixtureMessage::new(fixture["decoded_message"]["name"].as_str().unwrap())
            .with_signal(
                "speed_mps",
                SignalValue::Number(
                    fixture["decoded_message"]["signals"]["speed_mps"]
                        .as_f64()
                        .unwrap(),
                ),
            )
            .with_signal(
                "brake_pressed",
                SignalValue::Boolean(
                    fixture["decoded_message"]["signals"]["brake_pressed"]
                        .as_bool()
                        .unwrap(),
                ),
            ),
    );

    let mut gateway = Gateway::new(decoder, SyntheticAdapter::default());
    let state = gateway
        .ingest(
            &frame,
            oas_can::decode::DecodeContext {
                timestamp_ns: fixture["context"]["timestamp_ns"].as_u64(),
                bus: fixture["context"]["bus"].as_u64().unwrap() as u8,
            },
        )
        .unwrap()
        .unwrap();

    assert_eq!(state.vehicle_speed_mps, Some(12.5));
    assert_eq!(state.brake.pressed, Some(false));
}
