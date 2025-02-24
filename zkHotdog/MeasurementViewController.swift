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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Setup AR scene view
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        view.addSubview(sceneView)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Setup measurement label
        measurementLabel = UILabel()
        measurementLabel.frame = CGRect(x: 0, y: 50, width: view.bounds.width, height: 50)
        measurementLabel.textAlignment = .center
        measurementLabel.textColor = .white
        measurementLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        measurementLabel.text = "Tap to set start point"
        view.addSubview(measurementLabel)
        
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
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: sceneView)
        
        // Perform hit test to find real-world position
        guard let query = sceneView.raycastQuery(from: location, 
                                               allowing: .estimatedPlane, 
                                               alignment: .any) else { return }
        
        guard let result = sceneView.session.raycast(query).first else { return }
        
        let hitPosition = result.worldTransform.columns.3
        let hitPoint = SCNVector3(hitPosition.x, hitPosition.y, hitPosition.z)
        
        if startPoint == nil {
            // Create start point
            startPoint = createSphereNode(at: hitPoint, color: .red)
            sceneView.scene.rootNode.addChildNode(startPoint!)
            measurementLabel.text = "Tap to set end point"
        } else if endPoint == nil {
            // Create end point
            endPoint = createSphereNode(at: hitPoint, color: .red)
            sceneView.scene.rootNode.addChildNode(endPoint!)
            
            // Create line between points
            createLineBetweenPoints()
            
            // Calculate and display distance
            let distance = calculateDistance()
            measurementLabel.text = String(format: "Distance: %.2f cm", distance * 100)
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
        
        // Reset label
        measurementLabel.text = "Tap to set start point"
    }
    
    @objc func captureImage() {
        // Only capture if we have a complete measurement
        guard startPoint != nil, endPoint != nil else {
            measurementLabel.text = "Set both points before capturing"
            return
        }
        
        // Take screenshot of current ARView
        UIGraphicsBeginImageContextWithOptions(sceneView.bounds.size, false, UIScreen.main.scale)
        sceneView.drawHierarchy(in: sceneView.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Save image to photo library
        if let image = image {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(imageSaved(_:didFinishSavingWithError:contextInfo:)), nil)
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
