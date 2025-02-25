//
//  MeasurementViewController.swift
//  zkHotdog
//
//  Created by Andrew Tretyakov on 2025-02-24.
//

import UIKit
import ARKit
import SceneKit

class MeasurementViewController: UIViewController, ARSCNViewDelegate {
    private var sceneView: ARSCNView!
    private var startPoint: SCNNode?
    private var endPoint: SCNNode?
    private var lineNode: SCNNode?
    private var measurementLabel: UILabel!
    private var centerReticle: UIImageView!
    private var addPointButton: UIButton!
    private var measurementState: MeasurementState = .ready
    
    // Enum to track the current state of measurement
    private enum MeasurementState {
        case ready
        case measuringStart
        case measuringEnd
        case complete
    }
    
    // Hide status bar for fullscreen
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // Hide home indicator on newer devices
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Setup AR scene view with full screen bounds
        sceneView = ARSCNView(frame: UIScreen.main.bounds)
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        view.addSubview(sceneView)
        
        // Setup center reticle
        centerReticle = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        centerReticle.center = view.center
        centerReticle.contentMode = .scaleAspectFit
        
        // Create a simple crosshair programmatically
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 50, height: 50), false, 0)
        let context = UIGraphicsGetCurrentContext()!
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        
        // Draw crosshair
        context.move(to: CGPoint(x: 25, y: 15))
        context.addLine(to: CGPoint(x: 25, y: 35))
        context.move(to: CGPoint(x: 15, y: 25))
        context.addLine(to: CGPoint(x: 35, y: 25))
        
        // Draw circle
        context.addEllipse(in: CGRect(x: 20, y: 20, width: 10, height: 10))
        
        context.strokePath()
        let crosshairImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        centerReticle.image = crosshairImage
        view.addSubview(centerReticle)
        
        // Setup measurement label
        measurementLabel = UILabel()
        measurementLabel.frame = CGRect(x: 0, y: 50, width: view.bounds.width, height: 50)
        measurementLabel.textAlignment = .center
        measurementLabel.textColor = .white
        measurementLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        measurementLabel.text = "Position the reticle and tap 'Add Point'"
        view.addSubview(measurementLabel)
        
        // Add point button
        addPointButton = UIButton(type: .system)
        addPointButton.setTitle("Add Point", for: .normal)
        addPointButton.frame = CGRect(x: (view.bounds.width - 120) / 2, y: view.bounds.height - 100, width: 120, height: 50)
        addPointButton.backgroundColor = UIColor.systemYellow
        addPointButton.setTitleColor(.black, for: .normal)
        addPointButton.layer.cornerRadius = 10
        addPointButton.addTarget(self, action: #selector(addPoint), for: .touchUpInside)
        view.addSubview(addPointButton)
        
        // Add reset button
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.frame = CGRect(x: 20, y: view.bounds.height - 100, width: 100, height: 50)
        resetButton.backgroundColor = UIColor.systemBlue
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.layer.cornerRadius = 10
        resetButton.addTarget(self, action: #selector(resetMeasurement), for: .touchUpInside)
        view.addSubview(resetButton)
        
        // Add capture button
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture", for: .normal)
        captureButton.frame = CGRect(x: view.bounds.width - 120, y: view.bounds.height - 100, width: 100, height: 50)
        captureButton.backgroundColor = UIColor.systemGreen
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.layer.cornerRadius = 10
        captureButton.addTarget(self, action: #selector(captureImage), for: .touchUpInside)
        view.addSubview(captureButton)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create AR configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Check if LiDAR is available
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            print("LiDAR is available and enabled")
        } else {
            print("LiDAR is not available on this device")
        }
        
        // Additional configurations
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @objc func addPoint() {
        // Get the center point of the screen
        let screenCenter = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        
        // Perform hit test from the center of the screen
        guard let query = sceneView.raycastQuery(from: screenCenter, 
                                               allowing: .estimatedPlane, 
                                               alignment: .any) else { return }
        
        guard let result = sceneView.session.raycast(query).first else { 
            // Provide feedback if no surface is detected
            measurementLabel.text = "No surface detected. Try again."
            return 
        }
        
        let hitPosition = result.worldTransform.columns.3
        let hitPoint = SCNVector3(hitPosition.x, hitPosition.y, hitPosition.z)
        
        switch measurementState {
        case .ready, .measuringStart:
            // Create start point
            startPoint?.removeFromParentNode() // Remove existing start point if any
            startPoint = createSphereNode(at: hitPoint, color: .red)
            sceneView.scene.rootNode.addChildNode(startPoint!)
            measurementLabel.text = "Move to end point and tap 'Add Point'"
            measurementState = .measuringEnd
            
            // Update button title
            addPointButton.setTitle("Add End Point", for: .normal)
            
        case .measuringEnd:
            // Create end point
            endPoint = createSphereNode(at: hitPoint, color: .red)
            sceneView.scene.rootNode.addChildNode(endPoint!)
            
            // Create line between points
            createLineBetweenPoints()
            
            // Calculate and display distance
            let distance = calculateDistance()
            measurementLabel.text = String(format: "Distance: %.2f cm", distance * 100)
            measurementState = .complete
            
            // Update button title
            addPointButton.setTitle("Update Measurement", for: .normal)
            
        case .complete:
            // Reset for a new measurement
            resetMeasurement()
            
            // Then add the new start point
            startPoint = createSphereNode(at: hitPoint, color: .red)
            sceneView.scene.rootNode.addChildNode(startPoint!)
            measurementLabel.text = "Move to end point and tap 'Add Point'"
            measurementState = .measuringEnd
            
            // Update button title
            addPointButton.setTitle("Add End Point", for: .normal)
        }
    }
    
    // This function will continuously update a preview of the measurement
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Only show preview line when we have a start point but not an end point
            if self.measurementState == .measuringEnd, let startPoint = self.startPoint {
                // Get the center point of the screen
                let screenCenter = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
                
                // Perform hit test from the center of the screen
                guard let query = self.sceneView.raycastQuery(from: screenCenter, 
                                                           allowing: .estimatedPlane, 
                                                           alignment: .any) else { return }
                
                guard let result = self.sceneView.session.raycast(query).first else { return }
                
                let hitPosition = result.worldTransform.columns.3
                let hitPoint = SCNVector3(hitPosition.x, hitPosition.y, hitPosition.z)
                
                // Remove existing preview line
                self.lineNode?.removeFromParentNode()
                
                // Create a preview line
                let lineGeometry = SCNGeometry.lineFrom(vector: startPoint.position, to: hitPoint)
                self.lineNode = SCNNode(geometry: lineGeometry)
                self.sceneView.scene.rootNode.addChildNode(self.lineNode!)
                
                // Calculate and display current distance
                let distance = sqrt(
                    pow(hitPoint.x - startPoint.position.x, 2) +
                    pow(hitPoint.y - startPoint.position.y, 2) +
                    pow(hitPoint.z - startPoint.position.z, 2)
                )
                
                self.measurementLabel.text = String(format: "Current: %.2f cm", distance * 100)
            }
        }
    }
    
    private func createSphereNode(at position: SCNVector3, color: UIColor) -> SCNNode {
        let sphere = SCNSphere(radius: 0.01)
        sphere.firstMaterial?.diffuse.contents = color
        
        let node = SCNNode(geometry: sphere)
        node.position = position
        
        return node
    }
    
    private func createLineBetweenPoints() {
        guard let start = startPoint?.position, let end = endPoint?.position else { return }
        
        // Create a line geometry between the two points
        let lineGeometry = SCNGeometry.lineFrom(vector: start, to: end)
        lineNode = SCNNode(geometry: lineGeometry)
        sceneView.scene.rootNode.addChildNode(lineNode!)
    }
    
    private func calculateDistance() -> Float {
        guard let start = startPoint?.position, let end = endPoint?.position else { return 0 }
        
        // Calculate distance using Euclidean distance formula
        let distance = sqrt(
            pow(end.x - start.x, 2) +
            pow(end.y - start.y, 2) +
            pow(end.z - start.z, 2)
        )
        
        return distance
    }
    
    @objc func resetMeasurement() {
        // Remove all nodes
        startPoint?.removeFromParentNode()
        endPoint?.removeFromParentNode()
        lineNode?.removeFromParentNode()
        
        // Reset variables
        startPoint = nil
        endPoint = nil
        lineNode = nil
        
        // Reset state
        measurementState = .ready
        
        // Reset UI
        measurementLabel.text = "Position the reticle and tap 'Add Point'"
        addPointButton.setTitle("Add Point", for: .normal)
    }
    
    @objc func captureImage() {
        // Only capture if we have a complete measurement
        guard measurementState == .complete, startPoint != nil, endPoint != nil else {
            measurementLabel.text = "Complete measurement before capturing"
            return
        }
        
        // Show saving indicator
        measurementLabel.text = "Capturing image..."
        
        // Use a delay to ensure UI updates before capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Take screenshot of current ARView
            UIGraphicsBeginImageContextWithOptions(self.sceneView.bounds.size, false, UIScreen.main.scale)
            self.sceneView.drawHierarchy(in: self.sceneView.bounds, afterScreenUpdates: true)
            
            if let image = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                
                // Save image to photo library
                UIImageWriteToSavedPhotosAlbum(
                    image, 
                    self, 
                    #selector(self.imageSaved(_:didFinishSavingWithError:contextInfo:)), 
                    nil
                )
            } else {
                UIGraphicsEndImageContext()
                self.measurementLabel.text = "Failed to capture image"
            }
        }
    }
    
    @objc func imageSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            measurementLabel.text = "Error saving: \(error.localizedDescription)"
        } else {
            measurementLabel.text = "Image saved with measurement"
        }
    }
}

// Extension for creating line geometry
extension SCNGeometry {
    static func lineFrom(vector vector1: SCNVector3, to vector2: SCNVector3) -> SCNGeometry {
        let indices: [Int32] = [0, 1]
        
        let source = SCNGeometrySource(vertices: [vector1, vector2])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.green
        geometry.materials = [material]
        
        return geometry
    }
}
