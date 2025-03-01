//
//  MeasurementViewController.swift
//  zkHotdog
//
//  Created by Andrew Tretyakov on 2025-02-24.
//

import UIKit
import ARKit
import SceneKit
import AudioToolbox

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
        
        // Add gradient overlay at the top for the measurement label
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 120)
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.6).cgColor,
            UIColor.black.withAlphaComponent(0.3).cgColor,
            UIColor.clear.cgColor
        ]
        let gradientView = UIView(frame: gradientLayer.frame)
        gradientView.layer.addSublayer(gradientLayer)
        view.addSubview(gradientView)
        
        // Setup an improved center reticle
        centerReticle = UIImageView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        centerReticle.center = view.center
        centerReticle.contentMode = .scaleAspectFit
        centerReticle.layer.shadowColor = UIColor.black.cgColor
        centerReticle.layer.shadowOffset = CGSize(width: 0, height: 0)
        centerReticle.layer.shadowOpacity = 0.7
        centerReticle.layer.shadowRadius = 3
        
        // Create an improved crosshair programmatically
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 60, height: 60), false, 0)
        let context = UIGraphicsGetCurrentContext()!
        
        // Draw outer circle
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.addEllipse(in: CGRect(x: 5, y: 5, width: 50, height: 50))
        context.strokePath()
        
        // Draw crosshair
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.5)
        context.move(to: CGPoint(x: 30, y: 15))
        context.addLine(to: CGPoint(x: 30, y: 45))
        context.move(to: CGPoint(x: 15, y: 30))
        context.addLine(to: CGPoint(x: 45, y: 30))
        
        // Draw center dot
        context.setFillColor(UIColor.systemGreen.cgColor)
        context.addEllipse(in: CGRect(x: 27, y: 27, width: 6, height: 6))
        context.fillPath()
        
        let crosshairImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        centerReticle.image = crosshairImage
        view.addSubview(centerReticle)
        
        // Setup measurement label with improved design
        measurementLabel = UILabel()
        measurementLabel.frame = CGRect(x: 20, y: 50, width: view.bounds.width - 40, height: 50)
        measurementLabel.textAlignment = .center
        measurementLabel.textColor = .white
        measurementLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        measurementLabel.layer.shadowColor = UIColor.black.cgColor
        measurementLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        measurementLabel.layer.shadowOpacity = 1.0
        measurementLabel.layer.shadowRadius = 3
        measurementLabel.text = "Position the reticle and tap 'Add Point'"
        view.addSubview(measurementLabel)
        
        // Create a bottom control panel with blur effect
        let blurEffect = UIBlurEffect(style: .dark)
        let controlPanel = UIVisualEffectView(effect: blurEffect)
        controlPanel.frame = CGRect(x: 0, y: view.bounds.height - 100, width: view.bounds.width, height: 100)
        view.addSubview(controlPanel)
        
        // Add buttons to control panel
        let buttonSpacing: CGFloat = 10
        let buttonHeight: CGFloat = 50
        let buttonWidth: CGFloat = (view.bounds.width - (buttonSpacing * 4)) / 3
        
        // Reset button
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.frame = CGRect(x: buttonSpacing, y: 25, width: buttonWidth, height: buttonHeight)
        resetButton.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.8)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        resetButton.layer.cornerRadius = 12
        resetButton.layer.borderWidth = 1
        resetButton.layer.borderColor = UIColor.systemBlue.cgColor
        resetButton.addTarget(self, action: #selector(resetMeasurement), for: .touchUpInside)
        
        // Add point button
        addPointButton = UIButton(type: .system)
        addPointButton.setTitle("Add Point", for: .normal)
        addPointButton.frame = CGRect(x: buttonWidth + (buttonSpacing * 2), y: 25, width: buttonWidth, height: buttonHeight)
        addPointButton.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.8)
        addPointButton.setTitleColor(.systemYellow, for: .normal)
        addPointButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        addPointButton.layer.cornerRadius = 12
        addPointButton.layer.borderWidth = 1
        addPointButton.layer.borderColor = UIColor.systemYellow.cgColor
        addPointButton.addTarget(self, action: #selector(addPoint), for: .touchUpInside)
        
        // Capture button
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Submit", for: .normal)
        captureButton.frame = CGRect(x: (buttonWidth * 2) + (buttonSpacing * 3), y: 25, width: buttonWidth, height: buttonHeight)
        captureButton.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.8)
        captureButton.setTitleColor(.systemGreen, for: .normal)
        captureButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        captureButton.layer.cornerRadius = 12
        captureButton.layer.borderWidth = 1
        captureButton.layer.borderColor = UIColor.systemGreen.cgColor
        captureButton.addTarget(self, action: #selector(captureImage), for: .touchUpInside)
        
        // Add buttons to control panel's content view
        controlPanel.contentView.addSubview(resetButton)
        controlPanel.contentView.addSubview(addPointButton)
        controlPanel.contentView.addSubview(captureButton)
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
        // Create haptic feedback
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.prepare()
        
        // Get the center point of the screen
        let screenCenter = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        
        // Perform hit test from the center of the screen
        guard let query = sceneView.raycastQuery(from: screenCenter, 
                                               allowing: .estimatedPlane, 
                                               alignment: .any) else { return }
        
        guard let result = sceneView.session.raycast(query).first else { 
            // Provide feedback if no surface is detected
            measurementLabel.text = "⚠️ No surface detected. Try again."
            // Error feedback
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
            return 
        }
        
        // Trigger haptic feedback on successful point placement
        feedback.impactOccurred()
        
        let hitPosition = result.worldTransform.columns.3
        let hitPoint = SCNVector3(hitPosition.x, hitPosition.y, hitPosition.z)
        
        switch measurementState {
        case .ready, .measuringStart:
            // Create animated start point with better visuals
            startPoint?.removeFromParentNode() // Remove existing start point if any
            startPoint = createAnimatedPointNode(at: hitPoint, color: .systemGreen)
            sceneView.scene.rootNode.addChildNode(startPoint!)
            
            measurementLabel.text = "Move to end point and tap 'Add Point'"
            measurementState = .measuringEnd
            
            // Update button title and appearance
            addPointButton.setTitle("Add End Point", for: .normal)
            addPointButton.layer.borderColor = UIColor.systemRed.cgColor
            addPointButton.setTitleColor(.systemRed, for: .normal)
            
        case .measuringEnd:
            // Create animated end point with better visuals
            endPoint = createAnimatedPointNode(at: hitPoint, color: .systemRed)
            sceneView.scene.rootNode.addChildNode(endPoint!)
            
            // Create line between points
            createLineBetweenPoints()
            
            // Calculate and display distance
            let distance = calculateDistance()
            showMeasurementCompletedAnimation()
            measurementLabel.text = String(format: "✅ Distance: %.2f cm", distance * 100)
            measurementState = .complete
            
            // Update button title and appearance
            addPointButton.setTitle("New Measurement", for: .normal)
            addPointButton.layer.borderColor = UIColor.systemGreen.cgColor
            addPointButton.setTitleColor(.systemGreen, for: .normal)
            
            // Success feedback
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
        case .complete:
            // Reset for a new measurement
            resetMeasurement()
            
            // Then add the new start point
            startPoint = createAnimatedPointNode(at: hitPoint, color: .systemGreen)
            sceneView.scene.rootNode.addChildNode(startPoint!)
            
            measurementLabel.text = "Move to end point and tap 'Add Point'"
            measurementState = .measuringEnd
            
            // Update button title and appearance
            addPointButton.setTitle("Add End Point", for: .normal)
            addPointButton.layer.borderColor = UIColor.systemRed.cgColor
            addPointButton.setTitleColor(.systemRed, for: .normal)
        }
    }
    
    // Removed floating label method as it's no longer needed
    
    private func showMeasurementCompletedAnimation() {
        // Animate the measurement label to indicate completion
        UIView.animate(withDuration: 0.3, animations: {
            self.measurementLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.measurementLabel.transform = CGAffineTransform.identity
            }
        })
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
        
        // Make sure the sphere is exactly at the measured point
        node.position = position
        
        return node
    }
    
    private func createAnimatedPointNode(at position: SCNVector3, color: UIColor) -> SCNNode {
        // Create a more visually appealing marker
        let sphere = SCNSphere(radius: 0.008)
        
        // Set up material with emission for glow effect
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color.withAlphaComponent(0.6)
        material.lightingModel = .physicallyBased
        sphere.firstMaterial = material
        
        // Create main node - precisely at the position
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3Zero // Position relative to parent
        
        // Add pulse animation
        let pulseAction = SCNAction.sequence([
            SCNAction.scale(to: 1.3, duration: 0.5),
            SCNAction.scale(to: 1.0, duration: 0.5)
        ])
        sphereNode.runAction(SCNAction.repeatForever(pulseAction))
        
        // Create outer glow sphere
        let outerSphere = SCNSphere(radius: 0.015)
        let outerMaterial = SCNMaterial()
        outerMaterial.diffuse.contents = color.withAlphaComponent(0.0)
        outerMaterial.emission.contents = color.withAlphaComponent(0.3)
        outerMaterial.transparent.contents = UIColor.white.withAlphaComponent(0.3)
        outerMaterial.lightingModel = .constant
        outerSphere.firstMaterial = outerMaterial
        
        let outerNode = SCNNode(geometry: outerSphere)
        outerNode.opacity = 0.7
        outerNode.position = SCNVector3Zero // Position relative to parent
        
        // Add pulse animation to outer sphere (opposite phase)
        let outerPulseAction = SCNAction.sequence([
            SCNAction.scale(to: 0.8, duration: 0.5),
            SCNAction.scale(to: 1.1, duration: 0.5)
        ])
        outerNode.runAction(SCNAction.repeatForever(outerPulseAction))
        
        // Create parent node to hold both spheres
        let parentNode = SCNNode()
        parentNode.position = position // Place the parent node exactly at the hit position
        parentNode.name = "measurement-point"
        parentNode.addChildNode(sphereNode)
        parentNode.addChildNode(outerNode)
        
        // Add appearance animation
        parentNode.opacity = 0
        parentNode.scale = SCNVector3(0.01, 0.01, 0.01)
        
        let appearAction = SCNAction.group([
            SCNAction.fadeIn(duration: 0.3),
            SCNAction.scale(to: 1.0, duration: 0.3)
        ])
        parentNode.runAction(appearAction)
        
        return parentNode
    }
    
    private func createLineBetweenPoints() {
        guard let start = startPoint?.position, let end = endPoint?.position else { return }
        
        // Create a line geometry between the two points
        let lineGeometry = SCNGeometry.lineFrom(vector: start, to: end)
        
        // Create material with improved appearance
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemBlue
        material.emission.contents = UIColor.systemBlue.withAlphaComponent(0.7)
        material.lightingModel = .constant
        lineGeometry.materials = [material]
        
        // Create a node for the line
        lineNode = SCNNode(geometry: lineGeometry)
        lineNode?.name = "measurement-line"
        
        // Add a dash pattern animation to make the line more dynamic
        let dashLength: CGFloat = 0.01
        let dashSpacing: CGFloat = 0.01
        let totalLength = dashLength + dashSpacing
        
        // Create a repeating pattern with SCNTransaction
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.completionBlock = {
            // Create a repeating animation
            let dashAnimation = CABasicAnimation(keyPath: "lineDashPattern")
            dashAnimation.fromValue = [dashLength, dashSpacing, dashLength, dashSpacing * 3]
            dashAnimation.toValue = [dashLength, dashSpacing * 3, dashLength, dashSpacing]
            dashAnimation.duration = 1.0
            dashAnimation.repeatCount = .infinity
            material.setValue(dashAnimation, forKey: "lineDashPattern")
        }
        SCNTransaction.commit()
        
        // Create small animated indicators along the line
        addDistanceIndicatorsAlongLine(from: start, to: end)
        
        // Add line to scene with a grow animation
        lineNode!.opacity = 0
        sceneView.scene.rootNode.addChildNode(lineNode!)
        
        // Animate the line appearance
        let growAction = SCNAction.sequence([
            SCNAction.fadeIn(duration: 0.2),
            SCNAction.scale(to: 1.05, duration: 0.2),
            SCNAction.scale(to: 1.0, duration: 0.2)
        ])
        lineNode!.runAction(growAction)
    }
    
    private func addDistanceIndicatorsAlongLine(from start: SCNVector3, to end: SCNVector3) {
        // Calculate distance
        let distance = calculateDistanceBetween(start: start, end: end)
        let segmentCount = 5  // Number of segments to divide the line
        
        // Create a small indicator at the middle of the line
        let midPoint = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        
        // Add distance text at middle
        let distanceText = String(format: "%.1f cm", distance * 100)
        let textGeometry = SCNText(string: distanceText, extrusionDepth: 0)
        textGeometry.font = UIFont.systemFont(ofSize: 8, weight: .medium)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        textGeometry.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.5)
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.name = "measurement-text"
        
        // Scale and position the text
        textNode.scale = SCNVector3(0.002, 0.002, 0.002)
        textNode.position = SCNVector3(midPoint.x, midPoint.y + 0.02, midPoint.z)
        
        // Make text always face the camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.X, .Y, .Z]
        textNode.constraints = [billboardConstraint]
        
        // Add to scene with animation
        textNode.opacity = 0
        sceneView.scene.rootNode.addChildNode(textNode)
        
        let appearAction = SCNAction.sequence([
            SCNAction.wait(duration: 0.3), // wait for line to appear
            SCNAction.fadeIn(duration: 0.3),
            SCNAction.scale(to: 1.2, duration: 0.2),
            SCNAction.scale(to: 1.0, duration: 0.2)
        ])
        textNode.runAction(appearAction)
    }
    
    private func calculateDistanceBetween(start: SCNVector3, end: SCNVector3) -> Float {
        return sqrt(
            pow(end.x - start.x, 2) +
            pow(end.y - start.y, 2) +
            pow(end.z - start.z, 2)
        )
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
        // Remove all measurement nodes
        startPoint?.removeFromParentNode()
        endPoint?.removeFromParentNode()
        lineNode?.removeFromParentNode()
        
        // Remove all additional measurement nodes (like distance indicators)
        removeAllMeasurementNodes()
        
        // Reset variables
        startPoint = nil
        endPoint = nil
        lineNode = nil
        
        // Reset state
        measurementState = .ready
        
        // Reset UI
        measurementLabel.text = "Position the reticle and tap 'Add Point'"
        addPointButton.setTitle("Add Point", for: .normal)
        addPointButton.layer.borderColor = UIColor.systemYellow.cgColor
        addPointButton.setTitleColor(.systemYellow, for: .normal)
    }
    
    private func removeAllMeasurementNodes() {
        // Use a recursive function to find and remove all measurement-related nodes
        // This will ensure we catch all nodes, even those nested in parent nodes
        func removeNodeIfMeasurement(_ node: SCNNode) {
            // Create a copy of the childNodes array to avoid modification during iteration
            let childrenToCheck = node.childNodes
            
            // Process each child node first (depth-first)
            for childNode in childrenToCheck {
                removeNodeIfMeasurement(childNode)
            }
            
            // Check if this node is a measurement node
            if node.geometry is SCNText || 
               (node.name != nil && node.name!.contains("measurement")) {
                node.removeFromParentNode()
            }
        }
        
        // Start the recursive check from the root node
        // Create a temporary copy of the childNodes array to avoid modification during iteration
        let rootChildren = sceneView.scene.rootNode.childNodes
        for node in rootChildren {
            removeNodeIfMeasurement(node)
        }
    }
    
    @objc func captureImage() {
        // Haptic feedback on button press
        let buttonFeedback = UIImpactFeedbackGenerator(style: .light)
        buttonFeedback.impactOccurred()
        
        // Only capture if we have a complete measurement
        guard measurementState == .complete, 
              let startPointPos = startPoint?.position, 
              let endPointPos = endPoint?.position else {
            
            // Notify user with animation and haptic feedback
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
            
            // Show a more descriptive error message with animation
            UIView.transition(with: measurementLabel, duration: 0.3, options: .transitionCrossDissolve, animations: {
                self.measurementLabel.text = "⚠️ Complete measurement before submitting"
                self.measurementLabel.textColor = UIColor.systemRed
            }, completion: { _ in
                // Reset label color after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    UIView.transition(with: self.measurementLabel, duration: 0.3, options: .transitionCrossDissolve, animations: {
                        self.measurementLabel.textColor = UIColor.white
                    })
                }
            })
            return
        }
        
        // Show animated loading indicator
        animateLoadingState(withText: "Processing measurement...")
        
        // Use a delay to ensure UI updates before capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Add a flash effect when capturing
            self.addFlashEffect()
            
            // Take screenshot of current ARView
            UIGraphicsBeginImageContextWithOptions(self.sceneView.bounds.size, false, UIScreen.main.scale)
            self.sceneView.drawHierarchy(in: self.sceneView.bounds, afterScreenUpdates: true)
            
            if let image = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                
                // Convert image to data
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    self.showErrorMessage(message: "Failed to process image")
                    return
                }
                
                // Add timestamp and distance to the metadata
                let distance = self.calculateDistanceBetween(start: startPointPos, end: endPointPos)
                
                // Prepare point coordinates
                let startCoordinates = [
                    "x": startPointPos.x,
                    "y": startPointPos.y,
                    "z": startPointPos.z
                ]
                
                let endCoordinates = [
                    "x": endPointPos.x,
                    "y": endPointPos.y,
                    "z": endPointPos.z
                ]
                
                // Add metadata
                let metadata = [
                    "distance": distance * 100, // in cm
                    "timestamp": Date().timeIntervalSince1970
                ]
                
                // Send data to server
                self.sendMeasurementToServer(
                    imageData: imageData,
                    startPoint: startCoordinates,
                    endPoint: endCoordinates,
                    metadata: metadata
                )
            } else {
                UIGraphicsEndImageContext()
                self.showErrorMessage(message: "Failed to capture image")
            }
        }
    }
    
    private func animateLoadingState(withText text: String) {
        // Create activity indicator
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.color = .white
        loadingIndicator.center = CGPoint(x: measurementLabel.bounds.width - 25, y: measurementLabel.bounds.height / 2)
        loadingIndicator.startAnimating()
        
        // Add loading indicator to label
        measurementLabel.addSubview(loadingIndicator)
        
        // Update label text with animation
        UIView.transition(with: measurementLabel, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.measurementLabel.text = text
        })
    }
    
    private func addFlashEffect() {
        // Create a white overlay view for flash effect
        let flashView = UIView(frame: sceneView.bounds)
        flashView.backgroundColor = UIColor.white
        flashView.alpha = 0
        view.addSubview(flashView)
        
        // Animate flash effect
        UIView.animate(withDuration: 0.1, animations: {
            flashView.alpha = 0.8
        }, completion: { _ in
            UIView.animate(withDuration: 0.25, animations: {
                flashView.alpha = 0
            }, completion: { _ in
                flashView.removeFromSuperview()
            })
        })
        
        // Add camera shutter sound
        AudioServicesPlaySystemSound(1108) // Camera shutter sound
    }
    
    private func showErrorMessage(message: String) {
        // Remove any loading indicators
        for subview in measurementLabel.subviews {
            if let indicator = subview as? UIActivityIndicatorView {
                indicator.removeFromSuperview()
            }
        }
        
        // Show error with animation
        UIView.transition(with: measurementLabel, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.measurementLabel.text = "⚠️ " + message
            self.measurementLabel.textColor = UIColor.systemRed
        }, completion: { _ in
            // Reset label color after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                UIView.transition(with: self.measurementLabel, duration: 0.3, options: .transitionCrossDissolve, animations: {
                    self.measurementLabel.textColor = UIColor.white
                    self.measurementLabel.text = String(format: "Distance: %.2f cm", self.calculateDistance() * 100)
                })
            }
        })
        
        // Error haptic feedback
        let errorFeedback = UINotificationFeedbackGenerator()
        errorFeedback.notificationOccurred(.error)
    }
    
    private func sendMeasurementToServer(imageData: Data, startPoint: [String: Float], endPoint: [String: Float], metadata: [String: Any] = [:]) {
        // Server URL pointing to our Rust Axum server
        guard let url = URL(string: "http://172.20.10.2:3001/measurements") else {
            self.showErrorMessage(message: "Invalid server URL")
            return
        }
        
        // Create multipart request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"measurement.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add start point data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"startPoint\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        
        if let startPointData = try? JSONSerialization.data(withJSONObject: startPoint) {
            body.append(startPointData)
        }
        body.append("\r\n".data(using: .utf8)!)
        
        // Add end point data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"endPoint\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        
        if let endPointData = try? JSONSerialization.data(withJSONObject: endPoint) {
            body.append(endPointData)
        }
        body.append("\r\n".data(using: .utf8)!)
        
        // Add metadata if provided
        if !metadata.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"metadata\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
            
            if let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
                body.append(metadataData)
            }
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Close the boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Create task
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Remove loading indicators
                for subview in self.measurementLabel.subviews {
                    if let indicator = subview as? UIActivityIndicatorView {
                        indicator.removeFromSuperview()
                    }
                }
                
                if let error = error {
                    self.showErrorMessage(message: "Error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.showErrorMessage(message: "No data received from server")
                    return
                }
                
                do {
                    // Parse the response to get the measurement ID
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let measurementId = json["measurement_id"] as? String {
                        
                        // Success feedback
                        let successFeedback = UINotificationFeedbackGenerator()
                        successFeedback.notificationOccurred(.success)
                        
                        // Create the frontend URL with the measurement ID
                        let frontendUrl = "http://172.20.10.2:3000/\(measurementId)"
                        
                        if let redirectURL = URL(string: frontendUrl) {
                            // Show success message with animation
                            UIView.transition(with: self.measurementLabel, duration: 0.4, options: .transitionCrossDissolve, animations: {
                                self.measurementLabel.text = "✅ Measurement submitted successfully!"
                                self.measurementLabel.textColor = UIColor.systemGreen
                            })
                            
                            // Create a success overlay
                            self.showSuccessOverlay(withID: measurementId)
                            
                            // Open the URL in Safari after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                UIApplication.shared.open(redirectURL, options: [:], completionHandler: nil)
                            }
                        } else {
                            self.showErrorMessage(message: "Invalid redirect URL")
                        }
                    } else {
                        self.showErrorMessage(message: "Invalid response from server")
                    }
                } catch {
                    self.showErrorMessage(message: "Failed to parse server response")
                }
            }
        }
        
        // Start the task
        task.resume()
        
        // Update UI immediately
        UIView.transition(with: measurementLabel, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.measurementLabel.text = "Sending measurement to server..."
        })
    }
    
    private func showSuccessOverlay(withID id: String) {
        // Create a semi-transparent overlay
        let overlayView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        overlayView.frame = view.bounds
        overlayView.alpha = 0
        view.addSubview(overlayView)
        
        // Create a container for success info
        let container = UIView(frame: CGRect(x: 50, y: view.center.y - 100, width: view.bounds.width - 100, height: 200))
        container.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
        container.layer.cornerRadius = 20
        container.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        overlayView.contentView.addSubview(container)
        
        // Add success icon
        let checkmarkView = UIImageView(frame: CGRect(x: (container.bounds.width - 60) / 2, y: 20, width: 60, height: 60))
        let checkmarkImage = UIImage(systemName: "checkmark.circle.fill")?.withRenderingMode(.alwaysTemplate)
        checkmarkView.image = checkmarkImage
        checkmarkView.tintColor = UIColor.systemGreen
        checkmarkView.contentMode = .scaleAspectFit
        container.addSubview(checkmarkView)
        
        // Add success message
        let successLabel = UILabel(frame: CGRect(x: 20, y: 100, width: container.bounds.width - 40, height: 30))
        successLabel.text = "Measurement Submitted!"
        successLabel.textAlignment = .center
        successLabel.textColor = .white
        successLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        container.addSubview(successLabel)
        
        // Add ID label
        let idLabel = UILabel(frame: CGRect(x: 20, y: 140, width: container.bounds.width - 40, height: 20))
        idLabel.text = "ID: \(id)"
        idLabel.textAlignment = .center
        idLabel.textColor = .lightGray
        idLabel.font = UIFont.systemFont(ofSize: 14)
        container.addSubview(idLabel)
        
        // Animate the overlay appearance
        UIView.animate(withDuration: 0.5, animations: {
            overlayView.alpha = 1
            container.transform = CGAffineTransform.identity
        })
        
        // Dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.5, animations: {
                overlayView.alpha = 0
                container.transform = CGAffineTransform(translationX: 0, y: -50)
            }, completion: { _ in
                overlayView.removeFromSuperview()
            })
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
