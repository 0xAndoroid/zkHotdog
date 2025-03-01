use axum::{
    Router,
    body::Bytes,
    extract::{Multipart, Path, State},
    http::{StatusCode, header, Method},
    response::{IntoResponse, Json},
    routing::{get, post},
};
use tower_http::cors::{CorsLayer, Any};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    fs::{self, File},
    io::Write,
    net::SocketAddr,
    sync::{Arc, Mutex},
};
use uuid::Uuid;

// Data structures for our application
#[derive(Debug, Serialize, Deserialize, Clone)]
struct Point3D {
    x: f32,
    y: f32,
    z: f32,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct AttestationData {
    #[serde(rename = "attestationId")]
    attestation_id: u64,
    #[serde(rename = "merklePath", default)]
    merkle_path: Vec<String>,
    #[serde(rename = "leafCount", default)]
    leaf_count: u64,
    #[serde(default)]
    index: u64,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct Measurement {
    id: String,
    image_path: String,
    start_point: Point3D,
    end_point: Point3D,
    status: ProofStatus,
    attestation: Option<AttestationData>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
enum ProofStatus {
    Pending,
    Processing,
    Completed,
    Failed,
}

// AppState to store measurements
struct AppState {
    measurements: Mutex<HashMap<String, Measurement>>,
}

// Response for successful measurement submission
#[derive(Serialize)]
struct MeasurementResponse {
    url: String,
    measurement_id: String,
}

#[tokio::main]
async fn main() {
    // Ensure we have directories for storing data
    fs::create_dir_all("uploads").unwrap_or_else(|_| {
        println!("Failed to create uploads directory or it already exists");
    });

    fs::create_dir_all("proofs").unwrap_or_else(|_| {
        println!("Failed to create proofs directory or it already exists");
    });

    // Create shared application state
    let app_state = Arc::new(AppState {
        measurements: Mutex::new(HashMap::new()),
    });

    // Configure CORS
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE, Method::OPTIONS])
        .allow_headers(Any);

    // Build our application with routes
    let app = Router::new()
        .route("/measurements", post(handle_measurement))
        .route("/status/{id}", get(check_proof_status))
        .route("/img/{id}", get(serve_image))
        .layer(cors)
        .with_state(app_state);

    // Run the server
    let addr = SocketAddr::from(([0, 0, 0, 0], 3001));
    println!("Server listening on {}", addr);
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3001").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

// Handler for receiving measurement data
async fn handle_measurement(
    State(state): State<Arc<AppState>>,
    mut multipart: Multipart,
) -> Result<Json<MeasurementResponse>, (StatusCode, String)> {
    let mut image_data: Option<Bytes> = None;
    let mut start_point: Option<Point3D> = None;
    let mut end_point: Option<Point3D> = None;

    // Process multipart form data
    while let Some(field) = multipart.next_field().await.map_err(|e| {
        (StatusCode::BAD_REQUEST, format!("Failed to process multipart form: {}", e))
    })? {
        let name = field.name().unwrap_or("").to_string();

        match name.as_str() {
            "image" => {
                image_data = Some(field.bytes().await.map_err(|e| {
                    (StatusCode::BAD_REQUEST, format!("Failed to read image data: {}", e))
                })?);
            }
            "startPoint" => {
                let data = field.bytes().await.map_err(|e| {
                    (StatusCode::BAD_REQUEST, format!("Failed to read startPoint data: {}", e))
                })?;
                start_point = Some(serde_json::from_slice(&data).map_err(|e| {
                    (StatusCode::BAD_REQUEST, format!("Failed to parse startPoint JSON: {}", e))
                })?);
            }
            "endPoint" => {
                let data = field.bytes().await.map_err(|e| {
                    (StatusCode::BAD_REQUEST, format!("Failed to read endPoint data: {}", e))
                })?;
                end_point = Some(serde_json::from_slice(&data).map_err(|e| {
                    (StatusCode::BAD_REQUEST, format!("Failed to parse endPoint JSON: {}", e))
                })?);
            }
            _ => {
                println!("Unexpected field: {}", name);
            }
        }
    }

    // Ensure we have all required data
    let image_data =
        image_data.ok_or((StatusCode::BAD_REQUEST, "Missing image data".to_string()))?;
    let start_point =
        start_point.ok_or((StatusCode::BAD_REQUEST, "Missing start point data".to_string()))?;
    let end_point =
        end_point.ok_or((StatusCode::BAD_REQUEST, "Missing end point data".to_string()))?;

    let start_point = Point3D {
        x: (start_point.x * 100000.0).round(),
        y: (start_point.y * 100000.0).round(),
        z: (start_point.z * 100000.0).round(),
    };
    let end_point = Point3D {
        x: (end_point.x * 100000.0).round(),
        y: (end_point.y * 100000.0).round(),
        z: (end_point.z * 100000.0).round(),
    };

    // Generate a unique ID for this measurement
    let id = Uuid::new_v4().to_string();

    // Save the image to disk
    let file_name = format!("{}.jpg", id);
    let image_path = format!("uploads/{}", file_name);
    save_file(&image_path, &image_data)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to save image: {}", e)))?;

    // Create a new measurement record
    let measurement = Measurement {
        id: id.clone(),
        image_path,
        start_point,
        end_point,
        status: ProofStatus::Pending,
        attestation: None,
    };

    // Store the measurement in our app state
    {
        let mut measurements = state.measurements.lock().unwrap();
        measurements.insert(id.clone(), measurement.clone());
    }

    // Start the proof generation process in the background
    tokio::spawn(start_proof_process(state.clone(), id.clone()));

    // Return response with URL to check status
    Ok(Json(MeasurementResponse {
        url: format!("http://localhost:3000/status/{}", id),
        measurement_id: id,
    }))
}

// Helper function to save files
fn save_file(path: &str, data: &[u8]) -> std::io::Result<()> {
    let mut file = File::create(path)?;
    file.write_all(data)?;
    Ok(())
}

// Background task to start the proof process
async fn start_proof_process(state: Arc<AppState>, id: String) {
    // Get a clone of the measurement before locking for update
    let measurement = {
        let measurements = state.measurements.lock().unwrap();
        if let Some(m) = measurements.get(&id) {
            m.clone()
        } else {
            println!("Measurement not found: {}", id);
            return;
        }
    };

    // Update status to Processing
    {
        let mut measurements = state.measurements.lock().unwrap();
        if let Some(m) = measurements.get_mut(&id) {
            m.status = ProofStatus::Processing;
        }
    }

    println!("Starting proof generation for measurement {}", id);

    // Call snarkjs to generate witness and proof
    let result = generate_snarkjs_proof(&id, &measurement).await;

    // Update status based on result
    if result.is_ok() {
        // Update status to Processing in a separate scope to release the lock
        {
            let mut measurements = state.measurements.lock().unwrap();
            if let Some(m) = measurements.get_mut(&id) {
                // Proof was generated successfully, now submit for verification
                m.status = ProofStatus::Processing;
            }
        } // Lock is released here

        // Now we can safely spawn a new task with a cloned state
        let state_clone = state.clone();
        let id_clone = id.clone();
        tokio::spawn(async move {
            println!("Submitting proof {} to zkVerify network...", id_clone);

            // Run the TypeScript client using Node.js
            let verify_result = tokio::process::Command::new("node")
                .args(["dist/verify_client.js", &id_clone])
                .current_dir(".") // Run from the current directory
                .status()
                .await;

            // Update status based on verification result
            let mut measurements = state_clone.measurements.lock().unwrap();
            if let Some(m) = measurements.get_mut(&id_clone) {
                m.status = match verify_result {
                    Ok(status) if status.success() => {
                        println!("Proof {} verified successfully on zkVerify network", id_clone);
                        ProofStatus::Completed
                    }
                    _ => {
                        println!("Proof {} verification failed on zkVerify network", id_clone);
                        ProofStatus::Failed
                    }
                };
            }
        });
    } else {
        // In case of error, update status to Failed
        let mut measurements = state.measurements.lock().unwrap();
        if let Some(m) = measurements.get_mut(&id) {
            println!("Proof generation failed: {:?}", result.err());
            m.status = ProofStatus::Failed;
        }
    }
}

// Use snarkjs to generate witness and proof
async fn generate_snarkjs_proof(id: &str, measurement: &Measurement) -> Result<(), String> {
    println!("Generating ZK proof using snarkjs for measurement {}", id);

    // Create a directory for this proof
    let proof_dir = format!("proofs/{}", id);
    fs::create_dir_all(&proof_dir)
        .map_err(|e| format!("Failed to create proof directory: {}", e))?;

    // Create input file for snarkjs
    let input_path = format!("{}/input.json", proof_dir);

    // Calculate the distance based on the coordinates
    let dx = measurement.end_point.x as i32 - measurement.start_point.x as i32;
    let dy = measurement.end_point.y as i32 - measurement.start_point.y as i32;
    let dz = measurement.end_point.z as i32 - measurement.start_point.z as i32;
    // Round to the nearest integer to ensure it's compatible with the circuit
    let distance_squared = (dx * dx + dy * dy + dz * dz) as u32;

    let input_json = serde_json::json!({
        "point1": [
            measurement.start_point.x,
            measurement.start_point.y,
            measurement.start_point.z
        ],
        "point2": [
            measurement.end_point.x,
            measurement.end_point.y,
            measurement.end_point.z
        ],
        "distance_squared": distance_squared
    });

    // Write input JSON to file
    let input_content = serde_json::to_string_pretty(&input_json)
        .map_err(|e| format!("Failed to serialize input JSON: {}", e))?;
    fs::write(&input_path, input_content)
        .map_err(|e| format!("Failed to write input file: {}", e))?;

    // Paths for circuit artifacts
    let circuit_wasm = "circuit-compiled/zkHotdog_js/zkHotdog.wasm";
    // let circuit_r1cs = "circuit/zkHotdog.r1cs";
    let proving_key = "keys/zkHotdog_final.zkey";

    // Path for witness and proof output
    let witness_path = format!("{}/witness.wtns", proof_dir);
    let proof_path = format!("{}/proof.json", proof_dir);
    let public_path = format!("{}/public.json", proof_dir);

    // Step 1: Generate witness
    println!("Generating witness...");
    let witness_status = tokio::process::Command::new("node")
        .args([
            "circuit-compiled/zkHotdog_js/generate_witness.js",
            circuit_wasm,
            &input_path,
            &witness_path,
        ])
        .status()
        .await
        .map_err(|e| format!("Failed to execute witness generation: {}", e))?;

    if !witness_status.success() {
        return Err("Witness generation failed".to_string());
    }

    // Step 2: Generate proof
    println!("Generating proof...");
    let proof_status = tokio::process::Command::new("npx")
        .args([
            "snarkjs",
            "groth16",
            "prove",
            proving_key,
            &witness_path,
            &proof_path,
            &public_path,
        ])
        .status()
        .await
        .map_err(|e| format!("Failed to execute proof generation: {}", e))?;

    if !proof_status.success() {
        return Err("Proof generation failed".to_string());
    }

    println!("Successfully generated proof for measurement {}", id);
    Ok(())
}

// Handler to check proof status
async fn check_proof_status(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<Json<Measurement>, (StatusCode, String)> {
    let mut measurements = state.measurements.lock().unwrap();

    if let Some(measurement) = measurements.get_mut(&id) {
        // If the status is completed, check for attestation data
        if matches!(measurement.status, ProofStatus::Completed) && measurement.attestation.is_none()
        {
            // Check if attestation.json file exists
            let attestation_path = format!("proofs/{}/attestation.json", id);
            if std::path::Path::new(&attestation_path).exists() {
                // Read and parse the attestation data
                match fs::read_to_string(&attestation_path) {
                    Ok(content) => {
                        match serde_json::from_str::<AttestationData>(&content) {
                            Ok(attestation_data) => {
                                // Update the measurement with attestation data
                                measurement.attestation = Some(attestation_data);
                                println!("Found attestation data for measurement {}", id);
                            }
                            Err(e) => {
                                println!("Failed to parse attestation data: {}", e);
                            }
                        }
                    }
                    Err(e) => {
                        println!("Failed to read attestation file: {}", e);
                    }
                }
            }
        }

        Ok(Json(measurement.clone()))
    } else {
        Err((StatusCode::NOT_FOUND, format!("Measurement with ID {} not found", id)))
    }
}

// Handler to serve image files
async fn serve_image(Path(id): Path<String>) -> Result<impl IntoResponse, (StatusCode, String)> {
    // Construct path to the image file
    let file_path = format!("uploads/{}.jpg", id);

    // Check if the file exists
    if !std::path::Path::new(&file_path).exists() {
        return Err((StatusCode::NOT_FOUND, format!("Image with ID {} not found", id)));
    }

    // Read the file
    let image_data = match fs::read(&file_path) {
        Ok(data) => data,
        Err(e) => {
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Failed to read image: {}", e),
            ));
        }
    };

    Ok((
        [
            (header::CONTENT_TYPE, "image/jpeg".to_string()),
            (header::CONTENT_DISPOSITION, format!("inline; filename=\"{}.jpg\"", id)),
        ],
        image_data,
    ))
}
