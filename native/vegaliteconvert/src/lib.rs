use vl_convert_rs::converter::VlOpts;
use vl_convert_rs::{VlConverter, VlVersion};

rustler::atoms! {
    ok,
    error,
}

#[rustler::nif]
#[tokio::main]
async fn to_svg(spec: &str) -> (rustler::Atom, String) {
    let mut converter = VlConverter::new();
    let vl_spec: serde_json::Value = serde_json::from_str(spec).unwrap();

    let vega_spec = converter
        .vegalite_to_svg(
            vl_spec,
            VlOpts {
                vl_version: VlVersion::v5_5,
                ..Default::default()
            },
        )
        .await;

    let svg = match vega_spec {
        Ok(value) => value,
        Err(_) => return (error(), String::from("invalid spec")),
    };

    (ok(), svg)
}

rustler::init!("Elixir.TelemetryUI.VegaLiteConvert", [to_svg]);
