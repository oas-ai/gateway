#[cfg(target_os = "linux")]
fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("oas-gateway-host: {error}");
            std::process::ExitCode::FAILURE
        }
    }
}

#[cfg(target_os = "linux")]
fn run() -> Result<(), String> {
    use std::env;
    use std::io::{self, Write};

    use oas_can::hyundai_palisade_2020::HyundaiPalisade2020Decoder;
    use oas_car::hyundai_palisade_2020::HyundaiPalisade2020Adapter;
    use oas_gateway_host::Gateway;
    use oas_gateway_host::socketcan::SocketCanReceiver;

    let interface = env::args().nth(1).unwrap_or_else(|| "can0".into());
    let bus = env::args()
        .nth(2)
        .map(|value| value.parse::<u8>())
        .transpose()
        .map_err(|error| format!("invalid bus: {error}"))?
        .unwrap_or(0);
    let receiver =
        SocketCanReceiver::open(&interface, bus).map_err(|error| format!("{error:?}"))?;
    let mut gateway = Gateway::new(
        HyundaiPalisade2020Decoder,
        HyundaiPalisade2020Adapter::default(),
    );
    let stdout = io::stdout();
    let mut output = stdout.lock();

    loop {
        let Some((frame, context)) = receiver.receive().map_err(|error| format!("{error:?}"))?
        else {
            continue;
        };
        let Some(bytes) = gateway
            .ingest_protobuf(&frame, context)
            .map_err(|error| format!("{error:?}"))?
        else {
            continue;
        };
        let length = u32::try_from(bytes.len()).map_err(|_| "protobuf snapshot too large")?;
        output
            .write_all(&length.to_be_bytes())
            .and_then(|()| output.write_all(&bytes))
            .and_then(|()| output.flush())
            .map_err(|error| format!("stdout: {error}"))?;
    }
}

#[cfg(not(target_os = "linux"))]
fn main() {
    eprintln!("oas-gateway-host requires Linux SocketCAN");
}
