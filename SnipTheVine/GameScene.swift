
//  GameScene.swift
//  SnipTheVine

/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import SpriteKit
import AVFoundation

class GameScene: SKScene, SKPhysicsContactDelegate {
  
  private var particles: SKEmitterNode?
  private var crocodile: SKSpriteNode!
  private var prize: SKSpriteNode!
  private static var backgroundMusicPlayer: AVAudioPlayer!
  private var sliceSoundAction: SKAction!
  private var splashSoundAction: SKAction!
  private var nomNomSoundAction: SKAction!
  private var levelOver = false
  let chomp = UIImpactFeedbackGenerator(style: .heavy)
  let splash = UIImpactFeedbackGenerator(style: .light)
  private var vineCut = false
  
  override func didMove(to view: SKView) {
    setUpPhysics()
    setUpScenery()
    setUpPrize()
    setUpVines()
    setUpCrocodile()
    
    setUpAudio()
  }
  
  //MARK: - Level setup
  
  fileprivate func setUpPhysics() {
    physicsWorld.contactDelegate = self
    physicsWorld.gravity = CGVector(dx: 0.0, dy: -9.8)
    physicsWorld.speed = 1.0
  }
  
  fileprivate func setUpScenery() {
    let background = SKSpriteNode(imageNamed: ImageName.Background)
    background.anchorPoint = CGPoint(x: 0, y: 0)
    background.position = CGPoint(x: 0, y: 0)
    background.zPosition = Layer.Background
    background.size = CGSize(width: size.width, height: size.height)
    addChild(background)
    
    let water = SKSpriteNode(imageNamed: ImageName.Water)
    water.anchorPoint = CGPoint(x: 0, y: 0)
    water.position = CGPoint(x: 0, y: 0)
    water.zPosition = Layer.Foreground
    water.size = CGSize(width: size.width, height: size.height * 0.2139)
    addChild(water)
  }
  
  fileprivate func setUpPrize() {
    prize = SKSpriteNode(imageNamed: ImageName.Prize)
    prize.position = CGPoint(x: size.width * 0.5, y: size.height * 0.7)
    prize.zPosition = Layer.Prize
    prize.physicsBody = SKPhysicsBody(texture: SKTexture(imageNamed: ImageName.Prize), size: prize.size)
    prize.physicsBody?.categoryBitMask = PhysicsCategory.Prize
    prize.physicsBody?.collisionBitMask = 0
    prize.physicsBody?.density = 0.5
    
    addChild(prize)
  }
  
  //MARK: - Vine methods
  
  fileprivate func setUpVines() {
    // 1 load vine data
    let dataFile = Bundle.main.path(forResource: GameConfiguration.VineDataFile, ofType: nil)
    let vines = NSArray(contentsOfFile: dataFile!) as! [NSDictionary]
    
    // 2 add vines
    for i in 0..<vines.count {
      // 3 create vine
      let vineData = vines[i]
      let length = Int(vineData["length"] as! NSNumber)
      let relAnchorPoint = CGPointFromString(vineData["relAnchorPoint"] as! String)
      let anchorPoint = CGPoint(x: relAnchorPoint.x * size.width,
                                y: relAnchorPoint.y * size.height)
      let vine = VineNode(length: length, anchorPoint: anchorPoint, name: "\(i)")
      
      // 4 add to scene
      vine.addToScene(self)
      
      // 5 connect the other end of the vine to the prize
      vine.attachToPrize(prize)
    }
  }
  
  //MARK: - Croc methods
  
  fileprivate func setUpCrocodile() {
    crocodile = SKSpriteNode(imageNamed: ImageName.CrocMouthClosed)
    crocodile.position = CGPoint(x: size.width * 0.75, y: size.height * 0.33)
    crocodile.zPosition = Layer.Crocodile
    crocodile.physicsBody = SKPhysicsBody(texture: SKTexture(imageNamed: ImageName.CrocMask), size: crocodile.size)
    crocodile.physicsBody?.categoryBitMask = PhysicsCategory.Crocodile
    crocodile.physicsBody?.collisionBitMask = 0
    crocodile.physicsBody?.contactTestBitMask = PhysicsCategory.Prize
    crocodile.physicsBody?.isDynamic = false
    
    addChild(crocodile)
    
    animateCrocodile()
    
  }
  
  fileprivate func animateCrocodile() {
    let duration = 2.0 + drand48() * 2.0
    let open = SKAction.setTexture(SKTexture(imageNamed: ImageName.CrocMouthOpen))
    let wait = SKAction.wait(forDuration: duration)
    let close = SKAction.setTexture(SKTexture(imageNamed: ImageName.CrocMouthClosed))
    let sequence = SKAction.sequence([wait, open, wait, close])
    
    crocodile.run(SKAction.repeatForever(sequence))
  }
  
  fileprivate func runNomNomAnimationWithDelay(_ delay: TimeInterval) {
    crocodile.removeAllActions()
    
    let closeMouth = SKAction.setTexture(SKTexture(imageNamed: ImageName.CrocMouthClosed))
    let wait = SKAction.wait(forDuration: delay)
    let openMouth = SKAction.setTexture(SKTexture(imageNamed: ImageName.CrocMouthOpen))
    let sequence = SKAction.sequence([closeMouth, wait, openMouth, wait, closeMouth])
    
    crocodile.run(sequence)
  }
  
  //MARK: - Touch handling
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    vineCut = false
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      let startPoint = touch.location(in: self)
      let endPoint = touch.previousLocation(in: self)
      
      // 检查是否切割葡萄藤
      scene?.physicsWorld.enumerateBodies(alongRayStart: startPoint, end: endPoint,
                                          using: { (body, point, normal, stop) in
                                            self.checkIfVineCutWithBody(body)
      })
      
      // 产生一些好看的颗粒
      showMoveParticles(touchPosition: startPoint)
    }
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    particles?.removeFromParent()
    particles = nil
  }
  
  fileprivate func showMoveParticles(touchPosition: CGPoint) {
    if particles == nil {
      particles = SKEmitterNode(fileNamed: "Particle.sks")
      particles!.zPosition = 1
      particles!.targetNode = self
      addChild(particles!)
    }
    particles!.position = touchPosition
  }
  
  //MARK: - Game logic
  
  override func update(_ currentTime: TimeInterval) {
    // Called before each frame is rendered
    if levelOver {
      return
    }
    if prize.position.y <= 0 {
      run(splashSoundAction)
      splash.impactOccurred()
      switchToNewGameWithTransition(SKTransition.fade(withDuration: 1.0))
      levelOver = true
    }
  }
  
  func didBegin(_ contact: SKPhysicsContact) {
    if levelOver {
      return
    }
    if (contact.bodyA.node == crocodile && contact.bodyB.node == prize)
      || (contact.bodyA.node == prize && contact.bodyB.node == crocodile) {
      
      // shrink the pineapple away
      let shrink = SKAction.scale(to: 0, duration: 0.08)
      let removeNode = SKAction.removeFromParent()
      let sequence = SKAction.sequence([shrink, removeNode])
      prize.run(sequence)
      
      runNomNomAnimationWithDelay(0.15)
      
      run(nomNomSoundAction)
      chomp.impactOccurred()
      
      // transition to next level
      switchToNewGameWithTransition(SKTransition.doorway(withDuration: 1.0))
      levelOver = true
    }
  }
  
  fileprivate func checkIfVineCutWithBody(_ body: SKPhysicsBody) {
    if vineCut && !GameConfiguration.CanCutMultipleVinesAtOnce {
      return
    }
    
    let node = body.node!
    
    // if it has a name it must be a vine node
    if let name = node.name {
      // snip the vine
      node.removeFromParent()
      
      // fade out all nodes matching name
      enumerateChildNodes(withName: name, using: { (node, stop) in
        let fadeAway = SKAction.fadeOut(withDuration: 0.25)
        let removeNode = SKAction.removeFromParent()
        let sequence = SKAction.sequence([fadeAway, removeNode])
        node.run(sequence)
      })
      
      crocodile.removeAllActions()
      crocodile.texture = SKTexture(imageNamed: ImageName.CrocMouthOpen)
      animateCrocodile()
      
      run(sliceSoundAction)
    }
    
    vineCut = true
  }
  
  fileprivate func switchToNewGameWithTransition(_ transition: SKTransition) {
    let delay = SKAction.wait(forDuration: 1)
    let sceneChange = SKAction.run({
      let scene = GameScene(size: self.size)
      self.view?.presentScene(scene, transition: transition)
    })
    
    run(SKAction.sequence([delay, sceneChange]))
  }
  
  //MARK: - Audio
  
  fileprivate func setUpAudio() {
    if GameScene.backgroundMusicPlayer == nil {
      let backgroundMusicURL = Bundle.main.url(forResource: SoundFile.BackgroundMusic, withExtension: nil)
      
      do {
        let theme = try AVAudioPlayer(contentsOf: backgroundMusicURL!)
        GameScene.backgroundMusicPlayer = theme
        
      } catch {
        // 无法加载文件 :[
      }
      
      GameScene.backgroundMusicPlayer.numberOfLoops = -1
    }
    if !GameScene.backgroundMusicPlayer.isPlaying {
      GameScene.backgroundMusicPlayer.play()
    }
    sliceSoundAction = SKAction.playSoundFileNamed(SoundFile.Slice, waitForCompletion: false)
    splashSoundAction = SKAction.playSoundFileNamed(SoundFile.Splash, waitForCompletion: false)
    nomNomSoundAction = SKAction.playSoundFileNamed(SoundFile.NomNom, waitForCompletion: false)
  }
  
}
