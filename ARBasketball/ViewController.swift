//
//  ViewController.swift
//  ARBasketball
//
//  Created by Николай Никитин on 29.09.2021.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
  // MARK: - Outlets
  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet weak var scoreLabel: UILabel!
  @IBOutlet weak var ballsLeftLabel: UILabel!

  // MARK: - Properties
  let configuration = ARWorldTrackingConfiguration()
  private var score = 0 {
    didSet{
      DispatchQueue.main.async {
        self.scoreLabel.text = "SCORE: \(self.score)"
      }
    }
  }
 private  var ballsLeft = 10 {
    didSet{
      if ballsLeft <= 0 {
        DispatchQueue.main.async { self.performSegue(withIdentifier: "Result Segue", sender: nil) }
        self.ballsLeft = 10
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {self.score = 0})
      }
      DispatchQueue.main.async { self.ballsLeftLabel.text = "\(self.ballsLeft)/10" }
    }
  }
 private var isHoopAdded = false {
    didSet {
      configuration.planeDetection = []
      sceneView.session.run(configuration, options: .removeExistingAnchors)
    }
  }

  //MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()

    sceneView.autoenablesDefaultLighting = true

    // Set the view's delegate
    sceneView.delegate = self

    // Let's make the controller a delegate of contacts of the physical world.
    sceneView.scene.physicsWorld.contactDelegate = self

    // Show statistics such as fps and timing information
    sceneView.showsStatistics = false
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // Detect vertical & horizontal plane
    configuration.planeDetection = [.vertical, .horizontal]
    // Run the view's session
    sceneView.session.run(configuration)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // Pause the view's session
    sceneView.session.pause()
  }
  //MARK: - Methods

 private func getBall() -> SCNNode? {
    // Get current frame
    guard let frame = sceneView.session.currentFrame else { return nil }

    // Get camera transform
    let cameraTransform = frame.camera.transform
    let matrixCameraTransform = SCNMatrix4(cameraTransform)

    //Ball geometry
    let ball = SCNSphere(radius: 0.125)
    ball.firstMaterial?.diffuse.contents = UIImage(named: "ball")

    //Ball node created
    let ballNode = SCNNode(geometry: ball)

    //Ball physics
    ballNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ballNode))
    ballNode.physicsBody?.categoryBitMask = 3
    ballNode.physicsBody?.contactTestBitMask = 1

    // Calculate matrix force for pushing the ball
    let power = Float(10)
    let x = -matrixCameraTransform.m31 * power
    let y = -matrixCameraTransform.m32 * power
    let z = -matrixCameraTransform.m33 * power
    let forceDirection = SCNVector3(x,y,z)

    //Apply force
    ballNode.physicsBody?.applyForce(forceDirection, asImpulse: true)

    // Assign camera position to ball
    ballNode.simdTransform = cameraTransform
    ballNode.name = "ball"
    return ballNode
  }

  private func getCounter() -> SCNNode{
    // Add counter Node
    let scene = SCNScene(named: "Hoop.scn", inDirectory: "art.scnassets")!
    let counterNode = scene.rootNode.childNode(withName: "counter", recursively: false)!

    // Add counter Node phisics
    counterNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
    counterNode.opacity = 0
    counterNode.physicsBody?.categoryBitMask = 1
    counterNode.physicsBody?.contactTestBitMask = 0
    counterNode.physicsBody?.collisionBitMask = -1
    return counterNode
  }

  private func getHoopNode() -> SCNNode{
    let scene = SCNScene(named: "Hoop.scn", inDirectory: "art.scnassets")!
    let hoopNode = scene.rootNode.childNode(withName: "board", recursively: false)!
    // Add physics nodes
    hoopNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: hoopNode, options:[SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
    hoopNode.physicsBody?.categoryBitMask = 2
    hoopNode.physicsBody?.contactTestBitMask = 0
    hoopNode.physicsBody?.collisionBitMask = -3
    // Rotate hoop node to make it vertical
    hoopNode.eulerAngles.x -= .pi / 2
    return hoopNode
  }

  private func getPlane(for anchor: ARPlaneAnchor) -> SCNNode{
    let extent = anchor.extent
    let plane = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.z))
    plane.firstMaterial?.diffuse.contents = UIImage(named: "tracker.png")
    let planeNode = SCNNode(geometry: plane)
    planeNode.opacity = 0.75

    // Rotate plane
    planeNode.eulerAngles.x -= .pi / 2
    return planeNode
  }

  private func updatePlaneNode(_ node: SCNNode, for anchor: ARPlaneAnchor){
    guard let planeNode = node.childNodes.first, let plane = planeNode.geometry as? SCNPlane else { return }

    //Change plane node to center
    planeNode.simdPosition = anchor.center

    // Change plane size
    let extent = anchor.extent
    plane.height = CGFloat(extent.z)
    plane.width = CGFloat(extent.x)

  }

  // MARK: - ARSCNViewDelegate
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else { return }
    //Add the hoop to the center of detected vertical plane
    node.addChildNode(getPlane(for: planeAnchor))

  }
  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else { return }

    //Update plane node
    updatePlaneNode(node, for: planeAnchor)
  }

  // MARK: - SCNPhysicsContactDelegate
  func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
    guard let nodeABitMask = contact.nodeA.physicsBody?.categoryBitMask,
          let nodeBBitMask = contact.nodeB.physicsBody?.categoryBitMask,
          nodeABitMask & nodeBBitMask == 3 & 1 else { return }
    let explosion = SCNParticleSystem(named: "Explosion.scnp", inDirectory: "art.scnassets")!
    let explosionNode = SCNNode()
    explosionNode.position = contact.nodeB.presentation.position
    sceneView.scene.rootNode.addChildNode(explosionNode)
    explosionNode.addParticleSystem(explosion)
    contact.nodeB.removeFromParentNode()
    score += 1
  }

  //MARK: - Actions
  @IBAction func userTapped(_ sender: UITapGestureRecognizer) {
    if isHoopAdded {
      // Add basketballs
      guard let ballNode = getBall() else { return }
      sceneView.scene.rootNode.addChildNode(ballNode)
      ballsLeft -= 1
      DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {ballNode.removeFromParentNode()})
    } else {
      let location = sender.location(in: sceneView)
      guard let result = sceneView.hitTest(location, types: .existingPlaneUsingExtent).first else { return }
      guard let anchor = result.anchor as? ARPlaneAnchor, anchor.alignment == .vertical else { return }
      //Get hoopNode and set it's position to place of user's touch
      let hoopNode = getHoopNode()
      hoopNode.simdTransform = result.worldTransform
      // Rotate node by 90
      hoopNode.eulerAngles.x -= .pi / 2
      let counterNode = getCounter()
      sceneView.scene.rootNode.addChildNode(hoopNode)
      hoopNode.addChildNode(counterNode)
      isHoopAdded = true
    }
  }
  @IBSegueAction func resultSegue(_ coder: NSCoder) -> ResultViewController? {
    return ResultViewController(coder: coder, score)
  }
  @IBAction func unwind (_ seque: UIStoryboardSegue){ }
}
