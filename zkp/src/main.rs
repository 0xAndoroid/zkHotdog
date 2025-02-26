use axum::{
    Router,
    body::Bytes,
    extract::{Multipart, State},
    http::StatusCode,
    response::Json,
    routing::post,
};
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
struct Measurement {
    id: String,
    image_path: String,
    start_point: Point3D,
    end_point: Point3D,
    status: ProofStatus,
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

    // Create shared application state
    let app_state = Arc::new(AppState {
        measurements: Mutex::new(HashMap::new()),
    });

    // Build our application with routes
    let app = Router::new()
        .route("/measurements", post(handle_measurement))
        .route("/status/:id", post(check_proof_status))
        .with_state(app_state);

    // Run the server
    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    println!("Server listening on {}", addr);
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app.into_make_service()).await.unwrap();
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
    // Update status to Processing
    {
        let mut measurements = state.measurements.lock().unwrap();
        if let Some(measurement) = measurements.get_mut(&id) {
            measurement.status = ProofStatus::Processing;
        }
    }

    println!("Starting proof generation for measurement {}", id);

    // This is where we would call rapidsnark
    // For now, just simulate a process that would call rapidsnark
    let result = simulate_rapidsnark_call(&id).await;

    // Update status based on result
    {
        let mut measurements = state.measurements.lock().unwrap();
        if let Some(measurement) = measurements.get_mut(&id) {
            measurement.status =
                if result.is_ok() { ProofStatus::Completed } else { ProofStatus::Failed };
        }
    }
}

// Simulate calling rapidsnark (placeholder for now)
async fn simulate_rapidsnark_call(id: &str) -> Result<(), String> {
    println!("Simulating rapidsnark proving for {}", id);

    // In a real implementation, we would construct the proper command
    // to run rapidsnark with the appropriate parameters

    // Simulate a successful process execution
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    Ok(())
}

// Handler to check proof status
async fn check_proof_status(
    State(state): State<Arc<AppState>>,
    axum::extract::Path(id): axum::extract::Path<String>,
) -> Result<Json<Measurement>, (StatusCode, String)> {
    let measurements = state.measurements.lock().unwrap();

    if let Some(measurement) = measurements.get(&id) {
        Ok(Json(measurement.clone()))
    } else {
        Err((StatusCode::NOT_FOUND, format!("Measurement with ID {} not found", id)))
    }
}
