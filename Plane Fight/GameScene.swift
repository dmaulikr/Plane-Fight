//
//  GameScene.swift
//  Plane Fight
//
//  Created by Max Peiros on 7/21/16.
//  Copyright (c) 2016 Max Peiros. All rights reserved.
//

import SpriteKit
import GameplayKit
import CoreMotion

enum GameState {
    case ShowingLogo
    case Playing
    case Dead
}

let PlayerCategory       : UInt32 = 0x1 << 0
let EnemyCategory        : UInt32 = 0x1 << 1
let PlayerBulletCategory : UInt32 = 0x1 << 2
let EnemyBulletCategory  : UInt32 = 0x1 << 3
let GroundCategory       : UInt32 = 0x1 << 4
let SceneEdgeCategory    : UInt32 = 0x1 << 5

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    let motionManager: CMMotionManager = CMMotionManager()
    
    var player: SKSpriteNode!
    
    var backgroundMusic: SKAudioNode!
    
    var scoreLabel: SKLabelNode!
    var score = 0 {
        didSet {
            scoreLabel.text = "SCORE: \(score)"
        }
    }
    
    var startScreenLogo: SKSpriteNode!
    var gameOverLogo: SKSpriteNode!
    
    var gameState = GameState.ShowingLogo
    
    override func didMoveToView(view: SKView) {
        createPlayer()
        createSky()
        createBackground()
        createGround()
        createScore()
        createLogos()
        createMusic()
        
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self
        
        physicsBody = SKPhysicsBody(edgeLoopFromRect: frame)
        physicsBody!.restitution = 0
        physicsBody!.categoryBitMask = SceneEdgeCategory
        physicsBody!.contactTestBitMask = 0
        physicsBody!.collisionBitMask = PlayerCategory
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        switch gameState {
        case .ShowingLogo:
            gameState = .Playing
            
            let fadeOut = SKAction.fadeOutWithDuration(0.5)
            let fadeOutSequence = SKAction.sequence([fadeOut, SKAction.removeFromParent()])
            startScreenLogo.runAction(fadeOutSequence)
            
            createEnemies()
            motionManager.startAccelerometerUpdates()
            
        case .Playing:
            createPlayerBullet()
            
        case .Dead:
            let scene = GameScene(fileNamed: "GameScene")!
            scene.scaleMode = .ResizeFill
            let transition = SKTransition.moveInWithDirection(.Right, duration: 0)
            self.view?.presentScene(scene, transition: transition)
        }
    }
   
    override func update(currentTime: CFTimeInterval) {
        guard player != nil else { return }
        guard gameState == .Playing else { return }
        
        if let data = motionManager.accelerometerData {
            if fabs(data.acceleration.x) > 0.1 {
                player.physicsBody!.applyForce(CGVectorMake(0, -50.0 * CGFloat(data.acceleration.x)))
            } else {
                 player.physicsBody!.velocity = CGVectorMake(0, 0)
            }
        }
        
        let rand = GKRandomDistribution(lowestValue: 1, highestValue: 100)
        
        if rand.nextInt() == 1 {
            createEnemyBullet()
        }
    }
    
    func didBeginContact(contact: SKPhysicsContact) {
        if contact.bodyA.node == player || contact.bodyB.node == player {
            if let playerExplosion = SKEmitterNode(fileNamed: "PlayerExplosion") {
                playerExplosion.position = player.position
                addChild(playerExplosion)
            }
            
            if contact.bodyA.node?.name == "enemyBullet" {
                contact.bodyA.node?.removeFromParent()
            } else if contact.bodyB.node?.name == "enemyBullet" {
                contact.bodyB.node?.removeFromParent()
            }
            
            let sound = SKAction.playSoundFileNamed("explosion.wav", waitForCompletion: false)
            runAction(sound)
            
            gameState = .Dead
            gameOverLogo.alpha = 1
            backgroundMusic.runAction(SKAction.stop())
            
            let gameOverSound = SKAction.playSoundFileNamed("gameOver.wav", waitForCompletion: false)
            runAction(gameOverSound)
            
            motionManager.stopAccelerometerUpdates()
            
            player.removeFromParent()
            speed = 0
        }
        
        if contact.bodyA.node?.name == "enemy" || contact.bodyB.node?.name == "enemy" {
            if let enemyExplosion = SKEmitterNode(fileNamed: "EnemyExplosion") {
                var enemyExplosionPosition = CGPoint()
                
                if contact.bodyA.node?.name == "enemy" {
                    enemyExplosionPosition = contact.bodyA.node!.position
                    contact.bodyA.node?.removeFromParent()
                } else if contact.bodyB.node?.name == "enemy" {
                    enemyExplosionPosition = contact.bodyB.node!.position
                    contact.bodyB.node?.removeFromParent()
                }
                
                enemyExplosion.position = enemyExplosionPosition
                addChild(enemyExplosion)
            }
            
            if contact.bodyA.node?.name == "playerBullet" {
                contact.bodyA.node?.removeFromParent()
                score += 1
            } else if contact.bodyB.node?.name == "playerBullet" {
                contact.bodyB.node?.removeFromParent()
                score += 1
            }
            
            let sound = SKAction.playSoundFileNamed("explosion.wav", waitForCompletion: false)
            runAction(sound)
        }
    }
    
    func createPlayer() {
        let playerTexture = SKTexture(imageNamed: "player-1")
        player = SKSpriteNode(texture: playerTexture)
        player.zPosition = 10
        player.position = CGPoint(x: frame.width * 0.1, y: frame.height * 0.8)
        
        player.physicsBody = SKPhysicsBody(texture: playerTexture, size: playerTexture.size())
        player.physicsBody!.dynamic = true
        player.physicsBody!.restitution = 0
        player.physicsBody!.angularVelocity = 0
        player.physicsBody!.categoryBitMask = PlayerCategory
        player.physicsBody!.contactTestBitMask = EnemyCategory | EnemyBulletCategory | GroundCategory
        player.physicsBody!.collisionBitMask = SceneEdgeCategory
        
        addChild(player)
        
        let playerFrame2 = SKTexture(imageNamed: "player-2")
        let playerFrame3 = SKTexture(imageNamed: "player-3")
        let playerAnimation = SKAction.animateWithTextures([playerTexture, playerFrame2, playerFrame3, playerFrame2], timePerFrame: 0.01)
        let runForever = SKAction.repeatActionForever(playerAnimation)
        
        player.runAction(runForever)
    }
    
    func createEnemy() {
        let enemyTexture = SKTexture(imageNamed: "enemy-1")
        let enemy = SKSpriteNode(texture: enemyTexture)
        enemy.zPosition = 5
        enemy.name = "enemy"
        
        let maxY = Int(frame.height - enemyTexture.size().height)
        let minY = Int(enemyTexture.size().height * 2)
        let rand = GKRandomDistribution(lowestValue: minY, highestValue: maxY)
        let yPosition = CGFloat(rand.nextInt())
        enemy.position = CGPoint(x: frame.width + enemyTexture.size().width, y: yPosition)
        
        enemy.physicsBody = SKPhysicsBody(texture: enemyTexture, size: enemyTexture.size())
        enemy.physicsBody!.dynamic = true
        enemy.physicsBody!.categoryBitMask = EnemyCategory
        enemy.physicsBody!.contactTestBitMask = PlayerCategory | PlayerBulletCategory
        enemy.physicsBody!.collisionBitMask = 0
        
        addChild(enemy)
        
        let enemyFrame2 = SKTexture(imageNamed: "enemy-2")
        let enemyFrame3 = SKTexture(imageNamed: "enemy-3")
        let enemyAnimation = SKAction.animateWithTextures([enemyTexture, enemyFrame2, enemyFrame3, enemyFrame2], timePerFrame: 0.01)
        let runForever = SKAction.repeatActionForever(enemyAnimation)
        
        enemy.runAction(runForever)
        
        let moveMaxY = Int(frame.height - enemyTexture.size().height)
        let moveMinY = Int(enemyTexture.size().height * 2)
        let moveRand = GKRandomDistribution(lowestValue: moveMinY, highestValue: moveMaxY)
        let moveYPosition = CGFloat(moveRand.nextInt())
        
        let moveAction = SKAction.moveTo(CGPoint(x: -enemyTexture.size().width - 10, y: moveYPosition), duration: 10)
        let moveSequence = SKAction.sequence([moveAction, SKAction.removeFromParent()])
        
        enemy.runAction(moveSequence)
    }
    
    func createEnemies() {
        let create = SKAction.runBlock { [unowned self] in
            self.createEnemy()
        }
        
        let enemyWaitTime = SKAction.waitForDuration(5)
        let enemyCreationSequence = SKAction.sequence([create, enemyWaitTime])
        let repeatForever = SKAction.repeatActionForever(enemyCreationSequence)
        
        runAction(repeatForever)
    }
    
    func createPlayerBullet() {
        let playerBulletTexture = SKTexture(imageNamed: "playerBullet")
        let playerBullet = SKSpriteNode(texture: playerBulletTexture)
        playerBullet.zPosition = 20
        playerBullet.position = CGPoint(x: player.position.x + (player.size.width / 2), y: player.position.y)
        playerBullet.name = "playerBullet"
        
        playerBullet.physicsBody = SKPhysicsBody(texture: playerBulletTexture, size: playerBulletTexture.size())
        playerBullet.physicsBody!.dynamic = true
        playerBullet.physicsBody!.categoryBitMask = PlayerBulletCategory
        playerBullet.physicsBody!.contactTestBitMask = EnemyCategory
        playerBullet.physicsBody!.collisionBitMask = 0
        
        addChild(playerBullet)
        
        let moveAction = SKAction.moveToX(frame.width + playerBullet.size.width, duration: 5)
        let moveSequence = SKAction.sequence([moveAction, SKAction.removeFromParent()])
        
        playerBullet.runAction(moveSequence)
    }
    
    func createEnemyBullet() {
        let enemyBulletTexture = SKTexture(imageNamed: "enemyBullet")
        
        enumerateChildNodesWithName("enemy") { (node, stop) in
            if node.position.x > self.frame.midX {
                let enemyBullet = SKSpriteNode(texture: enemyBulletTexture)
                enemyBullet.zPosition = 15
                enemyBullet.position = CGPoint(x: node.position.x - (node.frame.size.width / 2), y: node.position.y)
                enemyBullet.name = "enemyBullet"
                
                enemyBullet.physicsBody = SKPhysicsBody(texture: enemyBulletTexture, size: enemyBulletTexture.size())
                enemyBullet.physicsBody!.dynamic = true
                enemyBullet.physicsBody!.categoryBitMask = EnemyBulletCategory
                enemyBullet.physicsBody!.contactTestBitMask = PlayerCategory
                enemyBullet.physicsBody!.collisionBitMask = 0
                
                self.addChild(enemyBullet)
                
                let moveAction = SKAction.moveToX(-self.frame.width - enemyBullet.size.width, duration: 5)
                let moveSequence = SKAction.sequence([moveAction, SKAction.removeFromParent()])
                
                enemyBullet.runAction(moveSequence)
            }
        }
    }
    
    func createSky() {
        let topSky = SKSpriteNode(color: UIColor(hue: 0.55, saturation: 0.14, brightness: 0.97, alpha: 1), size: CGSize(width: frame.width, height: frame.height * 0.67))
        topSky.anchorPoint = CGPoint(x: 0.5, y: 1)
        
        let bottomSky = SKSpriteNode(color: UIColor(hue: 0.55, saturation: 0.16, brightness: 0.96, alpha: 1), size: CGSize(width: frame.width, height: frame.height * 0.33))
        
        topSky.position = CGPoint(x: frame.midX, y: frame.height)
        bottomSky.position = CGPoint(x: frame.midX, y: bottomSky.frame.height / 2)
        
        topSky.zPosition = -40
        bottomSky.zPosition = -40
        
        addChild(topSky)
        addChild(bottomSky)
    }
    
    func createBackground() {
        let backgroundTexture = SKTexture(imageNamed: "background")
        
        for i in 0 ... 1 {
            let background = SKSpriteNode(texture: backgroundTexture)
            background.zPosition = -30
            background.anchorPoint = CGPointZero
            background.position = CGPoint(x: (backgroundTexture.size().width * CGFloat(i)) - CGFloat(1 * i), y: frame.height * 0.2)
            addChild(background)
            
            let moveLeft = SKAction.moveByX(-backgroundTexture.size().width, y: 0, duration: 20)
            let moveReset = SKAction.moveByX(backgroundTexture.size().width, y: 0, duration: 0)
            let moveLoop = SKAction.sequence([moveLeft, moveReset])
            let moveForever = SKAction.repeatActionForever(moveLoop)
            
            background.runAction(moveForever)
        }
    }
    
    func createGround() {
        let groundTexture = SKTexture(imageNamed: "ground")
        
        for i in 0 ... 1 {
            let ground = SKSpriteNode(texture: groundTexture)
            ground.zPosition = -10
            ground.position = CGPoint(x: (groundTexture.size().width / 2 + (groundTexture.size().width * CGFloat(i))), y: groundTexture.size().height / 2)
            
            ground.physicsBody = SKPhysicsBody(texture: ground.texture!, size: ground.texture!.size())
            ground.physicsBody!.dynamic = false
            ground.physicsBody!.categoryBitMask = GroundCategory
            ground.physicsBody!.contactTestBitMask = PlayerCategory
            ground.physicsBody!.collisionBitMask = 0
            
            addChild(ground)
            
            let moveLeft = SKAction.moveByX(-groundTexture.size().width, y: 0, duration: 5)
            let moveReset = SKAction.moveByX(groundTexture.size().width, y: 0, duration: 0)
            let moveLoop = SKAction.sequence([moveLeft, moveReset])
            let moveForever = SKAction.repeatActionForever(moveLoop)
            
            ground.runAction(moveForever)
        }
    }
    
    func createScore() {
        scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreLabel.fontSize = 20
        
        scoreLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 20)
        scoreLabel.horizontalAlignmentMode = .Center
        scoreLabel.text = "SCORE: 0"
        scoreLabel.fontColor = UIColor.blackColor()
        
        addChild(scoreLabel)
    }
    
    func createLogos() {
        startScreenLogo = SKSpriteNode(imageNamed: "startScreen")
        startScreenLogo.position = CGPoint(x: frame.midX, y: frame.midY)
        startScreenLogo.zPosition = 25
        addChild(startScreenLogo)
        
        gameOverLogo = SKSpriteNode(imageNamed: "gameOverScreen")
        gameOverLogo.position = CGPoint(x: frame.midX, y: frame.midY)
        gameOverLogo.alpha = 0
        gameOverLogo.zPosition = 30
        addChild(gameOverLogo)
    }
    
    func createMusic() {
        if let musicURL = NSBundle.mainBundle().URLForResource("music", withExtension: "m4a") {
            backgroundMusic = SKAudioNode(URL: musicURL)
            addChild(backgroundMusic)
        }
    }
    
}
