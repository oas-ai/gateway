//! Canonical vehicle model을 public protobuf contract로 변환한다.

use oas_car::vehicle_state as car;
use oas_sdk::vehicle::v1 as sdk;

/// Canonical `VehicleState` 전체를 `oas.vehicle.v1.VehicleState`로 변환한다.
pub fn vehicle_state(state: &car::VehicleState) -> sdk::VehicleState {
    sdk::VehicleState {
        timestamp_ns: state.timestamp_ns,
        vehicle_speed_mps: state.vehicle_speed_mps,
        acceleration_mps2: state.acceleration_mps2,
        wheels: state
            .wheels
            .iter()
            .map(|wheel| sdk::WheelState {
                position: match wheel.position {
                    car::WheelPosition::FrontLeft => sdk::WheelPosition::FrontLeft,
                    car::WheelPosition::FrontRight => sdk::WheelPosition::FrontRight,
                    car::WheelPosition::RearLeft => sdk::WheelPosition::RearLeft,
                    car::WheelPosition::RearRight => sdk::WheelPosition::RearRight,
                } as i32,
                speed_mps: wheel.speed_mps,
            })
            .collect(),
        steering: (state.steering.angle_rad.is_some() || state.steering.torque_nm.is_some())
            .then_some(sdk::SteeringState {
                angle_rad: state.steering.angle_rad,
                torque_nm: state.steering.torque_nm,
            }),
        brake: state.brake.pressed.map(|pressed| sdk::BrakeState {
            pressed: Some(pressed),
        }),
        accelerator: state
            .accelerator
            .position
            .map(|position| sdk::AcceleratorState {
                position: Some(position),
            }),
        gear: (state.gear.position != car::GearPosition::Unspecified).then_some(sdk::GearState {
            position: match state.gear.position {
                car::GearPosition::Unspecified => sdk::GearPosition::Unspecified,
                car::GearPosition::Park => sdk::GearPosition::Park,
                car::GearPosition::Reverse => sdk::GearPosition::Reverse,
                car::GearPosition::Neutral => sdk::GearPosition::Neutral,
                car::GearPosition::Drive => sdk::GearPosition::Drive,
            } as i32,
        }),
        cruise: state.cruise.enabled.map(|enabled| sdk::CruiseState {
            enabled: Some(enabled),
        }),
        doors: state
            .doors
            .iter()
            .map(|door| sdk::DoorState {
                position: match door.position {
                    car::DoorPosition::FrontLeft => sdk::DoorPosition::FrontLeft,
                    car::DoorPosition::FrontRight => sdk::DoorPosition::FrontRight,
                    car::DoorPosition::RearLeft => sdk::DoorPosition::RearLeft,
                    car::DoorPosition::RearRight => sdk::DoorPosition::RearRight,
                } as i32,
                open: door.open,
            })
            .collect(),
        seatbelts: state
            .seatbelts
            .iter()
            .map(|seatbelt| sdk::SeatbeltState {
                position: match seatbelt.position {
                    car::SeatPosition::Driver => sdk::SeatPosition::Driver,
                    car::SeatPosition::FrontPassenger => sdk::SeatPosition::FrontPassenger,
                    car::SeatPosition::RearLeft => sdk::SeatPosition::RearLeft,
                    car::SeatPosition::RearRight => sdk::SeatPosition::RearRight,
                } as i32,
                latched: seatbelt.latched,
            })
            .collect(),
    }
}

#[cfg(test)]
mod tests {
    use super::{car, sdk, vehicle_state};

    #[test]
    fn maps_nested_state_and_preserves_unknown_presence() {
        let mapped = vehicle_state(&car::VehicleState {
            wheels: vec![car::WheelState {
                position: car::WheelPosition::FrontLeft,
                speed_mps: Some(10.0),
            }],
            steering: car::SteeringState {
                angle_rad: Some(0.5),
                torque_nm: None,
            },
            brake: car::BrakeState {
                pressed: Some(false),
            },
            accelerator: car::AcceleratorState {
                position: Some(0.25),
            },
            gear: car::GearState {
                position: car::GearPosition::Drive,
            },
            cruise: car::CruiseState {
                enabled: Some(true),
            },
            doors: vec![car::DoorState {
                position: car::DoorPosition::RearRight,
                open: Some(false),
            }],
            seatbelts: vec![car::SeatbeltState {
                position: car::SeatPosition::Driver,
                latched: Some(true),
            }],
            ..car::VehicleState::default()
        });

        assert_eq!(
            mapped.wheels[0].position,
            sdk::WheelPosition::FrontLeft as i32
        );
        assert_eq!(mapped.steering.unwrap().torque_nm, None);
        assert_eq!(mapped.brake.unwrap().pressed, Some(false));
        assert_eq!(mapped.accelerator.unwrap().position, Some(0.25));
        assert_eq!(
            mapped.gear.unwrap().position,
            sdk::GearPosition::Drive as i32
        );
        assert_eq!(mapped.cruise.unwrap().enabled, Some(true));
        assert_eq!(
            mapped.doors[0].position,
            sdk::DoorPosition::RearRight as i32
        );
        assert_eq!(
            mapped.seatbelts[0].position,
            sdk::SeatPosition::Driver as i32
        );

        let empty = vehicle_state(&car::VehicleState::default());
        assert!(empty.steering.is_none());
        assert!(empty.gear.is_none());
    }
}
