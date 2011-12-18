/*
 *  ball.cpp
 *  Gopher
 *
 *  Created by Anthony Lobay on 1/19/10.
 *  Copyright 2010 3dDogStudios. All rights reserved.
 *
 */

#import <btBulletDynamicsCommon.h>

#import "GameEntityFactory.h"

#import "GraphicsComponent.h"
#import "GraphicsComponentFactory.h"
#import "GraphicsManager.h"

#import "PhysicsComponent.h"
#import "PhysicsComponentFactory.h"
#import "PhysicsManager.h"

#import "GamePlayManager.h"

#import "SpawnComponent.h"
#import "TargetComponent.h"
#import "ExplodableComponent.h"

#import "SceneManager.h"
#import "CannonController.h"
#import <vector>

using namespace std;
using namespace Dog3D;

const float kFixedHeight = 10;
const float kPegRestitution = 0.9f;

/// not added to phys mgr or game play mgr
Entity *GameEntityFactory::BuildBall( float radius, 
									 btVector3 &initialPosition, 
									 bool canRotate, 
									 float restitution, 
									 float mass,
									 ExplodableComponent::ExplosionType explosionType,  
									 float friction)
{
	
	Entity *newBall = new Entity();
#if DEBUG
	newBall->mDebugName = "Ball";
#endif
	
	newBall->SetPosition(initialPosition);
	
	NSString *textureName = nil;
	FXGraphicsComponent *fxComponent = NULL;
	
	switch (explosionType)
	{
		case ExplodableComponent::MUSHROOM:
		case ExplodableComponent::EXPLODE_SMALL:
			textureName = @"Black";
			fxComponent =  GraphicsComponentFactory::BuildBillBoardElement(radius*2.0f, radius* 2.0f, @"BombFuse", 2, 2, 4, radius + 0.1f);
			break;
			
		case ExplodableComponent::FIRE:
			textureName = @"Ball_Fire";
			fxComponent =  GraphicsComponentFactory::BuildFXElement(2, 2, @"ball.fire.sheet",4,4,16, true);
			break;
			
		case ExplodableComponent::ELECTRO:
			textureName = @"Ball_Electric";
			fxComponent = GraphicsComponentFactory::BuildFXElement(2, 2, @"ball.electric.sheet", 4,4,16, true);
			
			break;
			
		case ExplodableComponent::FREEZE:
			//textureName = @"Ball_Ice";
			//fxComponent =  GraphicsComponentFactory::BuildFXElement(2, 2, @"ball.ice.sheet", 4,4,16, true);
			break;
			
	}
	
	
	GraphicsComponent *graphicsComponent = 
		GraphicsComponentFactory::BuildSphere(radius , textureName );
	//GraphicsManager::Instance()->AddComponent(graphicsComponent);
	// added in order by scene manager
	
	newBall->SetGraphicsComponent(graphicsComponent);	
	
	PhysicsComponentInfo info;
	
	info.mIsStatic = false;
	info.mCanRotate = canRotate;
	info.mRestitution = restitution;
	info.mMass = mass;
	info.mCollisionGroup = GRP_BALL;
	info.mCollidesWith = info.mCollidesWith ; //| GRP_GHOST;
	info.mDoesNotSleep = true;
	
	info.mFriction = friction;
	
	
	PhysicsComponent *physicsComponent = 
	 PhysicsComponentFactory::BuildBall(radius, initialPosition, info);
	
	newBall->SetPhysicsComponent(physicsComponent);
	physicsComponent->SetKinematic(true);
	

	if(fxComponent != NULL)
	{
		newBall->AddComponent(fxComponent);
		GraphicsManager::Instance()->AddComponent(fxComponent);
	}
	

	{ 
		ExplodableComponent *explodeComponent = new ExplodableComponent(explosionType);		
		newBall->SetExplodable(explodeComponent);
	}
	// balls added to game mgr and phys mgr by cannon or scene mgr, depending on setup
	
	return newBall;
	
}

void GameEntityFactory::BuildCannon( float scale, btVector3 &initialPosition , 
									vector<Entity *> &newEntities, float rotationOffset,
									float rotationScale, float powerScale)
{
	
	Entity *cannon = new Entity();
#if DEBUG
	cannon->mDebugName = "Cannon";
#endif
	newEntities.push_back(cannon);
	cannon->SetPosition(initialPosition);
	cannon->SetYRotation(rotationOffset);
	
	//GraphicsComponent *graphicsComponent = 
	//GraphicsComponentFactory::BuildSprite(scale*2.0f, scale*2.0f, @"farmerSingle");
	//GraphicsManager::Instance()->AddComponent(graphicsComponent);
	// added in order by scene manager
	
	//graphicsComponent->SetOffset(btVector3(0,0,0 )); //1.5f));
	//cannon->SetGraphicsComponent(graphicsComponent);	
	
	// this is the graphics component
	HoldLastAnim *graphics = 
		GraphicsComponentFactory::BuildHoldLastAnim(scale*2.0f, scale*2.0f, @"farmer.sheet", 11);
	
	cannon->SetGraphicsComponent(graphics);
	
	GraphicsManager::Instance()->AddComponent(graphics);
	
	// no offset
	//fxComponent->SetOffset( btVector3(0,0,4.0f) );
	graphics->FollowParentRotation();
		
	CannonController *cannonController = new CannonController(powerScale);
	cannon->SetController(cannonController);
	// TODO  this is where a pool of balls would be built
	
	btVector3 pos(0, 1,14);
	
	Entity *line = BuildSprite(pos, 20, 1, @"Line", GraphicsManager::POST);
	newEntities.push_back(line);
	
	Entity *wheel = BuildSprite(pos, 8, 4, @"Arrows", GraphicsManager::POST);
	newEntities.push_back(wheel);
	{
#if DEBUG
		std::string textureName([@"Arrows" UTF8String]);
		wheel->mDebugName = textureName;
#endif
	}
	
	pos.setX(8);
	pos.setZ(-13);
	Entity *button = BuildSprite(pos, 4, 4, @"button", GraphicsManager::POST);
	newEntities.push_back(button);
	{
#if DEBUG
		std::string textureName([@"button" UTF8String]);
		button->mDebugName = textureName;
#endif
	}
	
	Entity *cannonUI = new Entity();
#if DEBUG
	cannonUI->mDebugName = "CannonUI";
#endif
	cannonUI->SetPosition(btVector3(0,0,0));
	newEntities.push_back(cannonUI);
	
	CannonUI *cannonUIControl = new CannonUI(cannon, wheel, button, rotationScale);
	cannonUIControl->SetRotationOffset(rotationOffset);
	
	cannonUI->SetController(cannonUIControl);
	
	
	GamePlayManager::Instance()->SetCannon( cannonController, cannonUIControl );
	
}

Entity *GameEntityFactory::BuildHedgeCircle( btVector3 &initialPosition, float radius )
{
	
	Entity *newHedge = new Entity();
#if DEBUG
	newHedge->mDebugName = "Hedge";
#endif
	
	/*GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildSphere(radius , kNumSlices, kNumRings );
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	newHedge->SetGraphicsComponent(graphicsComponent);	
	*/
	
	// no graphics component
	
	PhysicsComponentInfo info;
	info.mIsStatic = true;
	info.mRestitution = 0.9f;
	info.mCollisionGroup = GRP_FIXED;
	info.mCollidesWith =  GRP_GOPHER | GRP_BALL;
	
	
	// make this static (collider)
	// uses a ht of 10
	PhysicsComponent *phys = PhysicsComponentFactory::BuildCylinder(radius, kFixedHeight, initialPosition, info); 
	
	PhysicsManager::Instance()->AddComponent(  phys );
	
	newHedge->SetPhysicsComponent( phys );
	
	
	return newHedge;
	
}


Entity *GameEntityFactory::BuildFenceBox( btVector3 &initialPosition, btVector3 &halfExtents )
{
	
	Entity *newBox = new Entity();
#if DEBUG
	newBox->mDebugName = "Fence";
#endif
	
	// no graphics component
	btVector3 zero(0,0,0);
	
	/* uncomment this to debug fence collider
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildBox( initialPosition, halfExtents );
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	newBox->SetGraphicsComponent(graphicsComponent);	
	*/
	
	PhysicsComponentInfo info;
	info.mIsStatic = true;
	info.mRestitution =0.9f;
	info.mCollisionGroup = GRP_FIXED;
	info.mCollidesWith =  GRP_GOPHER | GRP_BALL;
	
	// make this static (collider)
	PhysicsComponent *phys = PhysicsComponentFactory::BuildBox( initialPosition, halfExtents ,0, info); 
	
	PhysicsManager::Instance()->AddComponent(  phys  );
	
	newBox->SetPhysicsComponent( phys );
	
	
	return newBox;
	
}


#if 0
Entity *GameEntityFactory::BuildGopherHUD( btVector3 &initialPosition, btVector3 &extents, float widthSpacing, int nGopherLives, bool alignLeft)
{
	Entity *hud = new Entity();
#if DEBUG
	hud->mDebugName = "HUD";
#endif	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildHUD( extents, widthSpacing, nGopherLives, alignLeft, @"GophFat");
	
	hud->SetGraphicsComponent(graphicsComponent);
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	
	hud->SetPosition(initialPosition);
	
	return hud;
}

Entity *GameEntityFactory::BuildCarrotHUD( btVector3 &initialPosition, btVector3 &extents, float widthSpacing, int nGopherLives, bool alignLeft)
{
	Entity *hud = new Entity();
#if DEBUG
	hud->mDebugName = "HUD";
#endif	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildHUD( extents, widthSpacing, nGopherLives, alignLeft, @"Carrot32");
	
	hud->SetGraphicsComponent(graphicsComponent);
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	
	hud->SetPosition(initialPosition);
	
	return hud;
}

Entity *GameEntityFactory::BuildHUDBackground( btVector3 &initialPosition, float width, float height)
{
	Entity *hud = new Entity();
#if DEBUG
	hud->mDebugName = "HUD";
#endif
	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildSprite(width, height, @"Square");
	
	hud->SetGraphicsComponent(graphicsComponent);
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	
	hud->SetPosition(initialPosition);
	
	return hud;
}

Entity *GameEntityFactory::BuildWin()
{
	Entity *hud = new Entity();
#if DEBUG
	hud->mDebugName = "WinHUD";
#endif	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildSprite(10, 15, @"YouWin");
	
	hud->SetGraphicsComponent(graphicsComponent);
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	
	btVector3 zero(0,0,0);
	hud->SetPosition(zero);
	
	return hud;
	
}

Entity *GameEntityFactory::BuildLost()
{
	Entity *hud = new Entity();
#if DEBUG
	hud->mDebugName = "LostHUD";
#endif
	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildSprite(10, 15, @"TryAgain");
	
	hud->SetGraphicsComponent(graphicsComponent);
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	
	
	btVector3 zero(0,0,0);
	hud->SetPosition(zero);
	
	return hud;
	
}
#endif

Entity *GameEntityFactory::BuildGround( btVector3 &initialPosition, float height, float width, const std::string *backgroundTexture, bool poolTable )
{
	
	Entity *newGround = new Entity();
	
#if DEBUG
	newGround->mDebugName = "Ground";
#endif 
	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildGroundPlane( height, width, backgroundTexture );
	GraphicsManager::Instance()->AddComponent(graphicsComponent, GraphicsManager::PRE);
	newGround->SetGraphicsComponent(graphicsComponent);	
	
	PhysicsComponentInfo info;
	info.mIsStatic = true;
	info.mRestitution = (poolTable) ? 0.4f : 0.9f;
	
	info.mCollisionGroup = GRP_FLOOR_CEIL;
	info.mFriction = poolTable ? 0.5f : 0.1;
	
	// TODO - if you want this to support explodables, add GRP_EXPLODABLES
	info.mCollidesWith =  GRP_GOPHER | GRP_BALL;
	
	PhysicsComponent *physicsGround = PhysicsComponentFactory::BuildPlane(initialPosition, 1, info);
	PhysicsManager::Instance()->AddComponent( physicsGround );
	newGround->SetPhysicsComponent(physicsGround);
		
	return newGround;
	
}


Entity *GameEntityFactory::BuildTopPlate( btVector3 &initialPosition )
{
	
	Entity *newGround = new Entity();
#if DEBUG
	newGround->mDebugName = "TopPlate";
#endif 
	
	PhysicsComponentInfo info;
	info.mIsStatic = true;
	info.mRestitution = 0.9f;
	info.mCollisionGroup = GRP_FLOOR_CEIL;
	info.mCollidesWith = GRP_GOPHER | GRP_BALL;
	
	PhysicsComponent *physicsGround = PhysicsComponentFactory::BuildPlane(initialPosition, -1, info);
	PhysicsManager::Instance()->AddComponent( physicsGround );
	newGround->SetPhysicsComponent(physicsGround);
	
	return newGround;
}

Dog3D::Entity *GameEntityFactory::BuildSprite( btVector3 &initialPosition, float w, float h, NSString *spriteName, GraphicsManager::RenderQueueOrder order)
{
	Entity *sprite = new Entity();
	sprite->SetPosition(initialPosition);
#if DEBUG
	sprite->mDebugName = std::string([spriteName UTF8String]);
#endif
	
	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildSprite( w, h, spriteName );
	GraphicsManager::Instance()->AddComponent(graphicsComponent, order);
	sprite->SetGraphicsComponent(graphicsComponent);	
	
	return sprite;
}

Dog3D::Entity *GameEntityFactory::BuildScreenSpaceSprite( btVector3 &initialPosition, float w, float h, NSString *spriteName, float duration)
{
	Entity *sprite = new Entity();
	sprite->SetPosition(initialPosition);
#if DEBUG
	sprite->mDebugName = std::string([spriteName UTF8String]);
#endif
	
	
	ScreenSpaceComponent *graphicsComponent = 
	dynamic_cast<ScreenSpaceComponent*> (GraphicsComponentFactory::BuildScreenSpaceSprite( w, h, spriteName, initialPosition, duration ));
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	sprite->SetGraphicsComponent(graphicsComponent);	
	
	return sprite;
}

#if 0
Dog3D::Entity *GameEntityFactory::BuildText( btVector3 &initialPosition, float w, float h, NSString *displayText)
{
	Entity *text = new Entity();
	text->SetPosition(initialPosition);
#if DEBUG
	text->mDebugName = std::string([displayText UTF8String]);
#endif
	text->SetYRotation(M_PI/2.0f);
	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildText( w, h, displayText );
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	text->SetGraphicsComponent(graphicsComponent);	
	
	return text;
}
#endif

// all boxes can rotate if not static
Entity *GameEntityFactory::BuildWall( btVector3 &initialPosition, btVector3 &halfExtents, float restitution )
{
	
	Entity *newBox = new Entity();
	
#if DEBUG
	newBox->mDebugName = "Wall";
#endif 
	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildBox( halfExtents );
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	newBox->SetGraphicsComponent(graphicsComponent);	
	
	
	PhysicsComponentInfo info;
	info.mIsStatic = true;
	info.mRestitution = 0.8f;
	info.mCollisionGroup = GRP_WALL;
	info.mCollidesWith = GRP_BALL;
	
	PhysicsComponent *physicsBox = PhysicsComponentFactory::BuildBox( initialPosition, halfExtents,0, info );
	PhysicsManager::Instance()->AddComponent( physicsBox  );
	newBox->SetPhysicsComponent( physicsBox );
	
	newBox->SetPosition(initialPosition);
	return newBox;
	
}


// basic rock like object
Entity *GameEntityFactory::BuildTexturedCollider( btVector3 &initialPosition, btVector3 &halfExtents, 
												 float yRotation, float restitution, NSString *textureName,
												 float graphicsScale)
{
	
	Entity *newBox = new Entity();
	newBox->SetPosition(initialPosition);
	
	btMatrix3x3 rotation;
	rotation.setEulerZYX(0, 0, yRotation);
	newBox->SetRotation(rotation);
	
#if DEBUG
	newBox->mDebugName = [textureName UTF8String];
#endif
	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildSprite(halfExtents.x()*2.0f * graphicsScale, 
																				 halfExtents.z()*2.0f * graphicsScale, 
																				 textureName);
	
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	newBox->SetGraphicsComponent(graphicsComponent);	
	
	PhysicsComponentInfo info;
	info.mIsStatic = true;
	info.mRestitution = restitution;
	info.mDoesNotSleep = false;
	info.mCollisionGroup = GRP_FIXED;
	info.mCollidesWith = GRP_BALL | GRP_GOPHER;
	
	PhysicsComponent *physicsBox = PhysicsComponentFactory::BuildBox( initialPosition, halfExtents, yRotation, info );
	//PhysicsComponent *physicsBox = PhysicsComponentFactory::BuildBall( halfExtents.x(), initialPosition, info );
	//PhysicsComponent *physicsBox = PhysicsComponentFactory::BuildCylinder(halfExtents.x(), 10,initialPosition,info);
	
	PhysicsManager::Instance()->AddComponent( physicsBox  );
	newBox->SetPhysicsComponent( physicsBox );
	
	
	return newBox;
	
}

// basic rock like object
Entity *GameEntityFactory::BuildCircularCollider( btVector3 &initialPosition, btVector3 &halfExtents, float restitution, NSString *textureName, float graphicsScale)
{
	
	Entity *newBox = new Entity();
	newBox->SetPosition(initialPosition);
#if DEBUG
	newBox->mDebugName = [textureName UTF8String];
#endif
	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildSprite(halfExtents.x()*2.0f*graphicsScale, halfExtents.z()*2.0f*graphicsScale, textureName);
	
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	newBox->SetGraphicsComponent(graphicsComponent);	
	
	PhysicsComponentInfo info;
	info.mIsStatic = true;
	info.mRestitution = restitution;
	info.mDoesNotSleep = false;
	info.mCollisionGroup = GRP_FIXED;
	info.mCollidesWith = GRP_BALL | GRP_GOPHER;
	
	PhysicsComponent *physicsBox = PhysicsComponentFactory::BuildCylinder(halfExtents.x(), kFixedHeight,initialPosition,info);
	
	PhysicsManager::Instance()->AddComponent( physicsBox  );
	newBox->SetPhysicsComponent( physicsBox );
	
	
	return newBox;
	
}

// basic rock like object
Entity *GameEntityFactory::BuildCircularExploder( btVector3 &initialPosition, btVector3 &halfExtents, 
												 NSString *textureName, float respawnTime, float graphicsScale,
												 ExplodableComponent::ExplosionType explosionType )
{
	
	Entity *newBox = new Entity();
	newBox->SetPosition(initialPosition);
#if DEBUG
	newBox->mDebugName = [textureName UTF8String];
#endif
	
	GraphicsComponent *graphicsComponent = GraphicsComponentFactory::BuildSprite(halfExtents.x()*2.0f*graphicsScale, 
																				 halfExtents.z()*2.0f*graphicsScale, 
																				 textureName);
	
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	newBox->SetGraphicsComponent(graphicsComponent);	
	
	PhysicsComponentInfo info;
	info.mIsStatic = true;
	info.mDoesNotSleep = false;
	// note that we force the explosion only on explode small
	info.mCollisionGroup =GRP_EXPLODABLE;
	info.mCollidesWith = GRP_BALL;
	
	info.mRestitution = kPegRestitution;
	
	PhysicsComponent *physicsBox = PhysicsComponentFactory::BuildCylinder(halfExtents.x(), kFixedHeight,initialPosition,info);
	
	PhysicsManager::Instance()->AddComponent( physicsBox  );
	newBox->SetPhysicsComponent( physicsBox );
	
	ExplodableComponent *explodable = NULL;
	
	switch (explosionType) {
		
		case ExplodableComponent::POP:
			explodable = new PopExplodable(ExplodableComponent::EXPLODE_SMALL, respawnTime, [textureName UTF8String]);
			
			//new PopExplodable(ExplodableComponent::EXPLODE_SMALL, respawnTime, [textureName UTF8String]);
			
			break;
			
		case ExplodableComponent::BUMPER:
			explodable = new BumperExplodable(ExplodableComponent::EXPLODE_SMALL, respawnTime, [textureName UTF8String]);
			
			break;
			
		default:
			explodable = new BumperExplodable(ExplodableComponent::EXPLODE_SMALL, respawnTime, [textureName UTF8String]);
			
			break;
	}
	
	newBox->SetExplodable(explodable);
	explodable->Prime();
	
	return newBox;
	
}


// builds a looping FX elt
Entity *GameEntityFactory::BuildFXElement(  btVector3 &initialPosition, btVector3 &extents, 
										  NSString *spriteSheet, int nTilesHigh, int nTilesWide, 
										  int nTiles, bool  renderInPreQueue)
{
	Entity *newElement = new Entity();
	newElement->SetPosition(initialPosition);
#if DEBUG
	newElement->mDebugName = "FXElement";
#endif
	
	FXGraphicsComponent *graphicsComponent = 
	GraphicsComponentFactory::BuildFXElement(extents.x(), extents.z(), spriteSheet, nTilesWide, nTilesHigh, nTiles, true, 1.0f/15.0f);

	
	// kick off default anim (won't do anything until the anim starts updating)
	graphicsComponent->StartAnimation(AnimatedGraphicsComponent::IDLE );
	
	GraphicsManager::Instance()->AddComponent(graphicsComponent, renderInPreQueue);
	newElement->SetGraphicsComponent(graphicsComponent);	
	
	// target (for caching node id's)	
	newElement->mActive = true;
	
	return newElement;
	
}

// builds a looping FX elt
// has a circular collider element
Entity *GameEntityFactory::BuildFXCircularCollider(  btVector3 &initialPosition, btVector3 &extents, 
										  NSString *spriteSheet, int nTilesHigh, int nTilesWide, 
										  int nTiles)
{
	Entity *newElement = new Entity();
	newElement->SetPosition(initialPosition);
#if DEBUG
	newElement->mDebugName = "FXElement";
#endif
	
	FXGraphicsComponent *graphicsComponent = 
	GraphicsComponentFactory::BuildFXElement(extents.x()*2.0f, extents.z()*2.0f, spriteSheet, nTilesWide, nTilesHigh, nTiles, true, 1.0f/15.0f);
	
	
	// kick off default anim (won't do anything until the anim starts updating)
	graphicsComponent->StartAnimation(AnimatedGraphicsComponent::IDLE );
	
	GraphicsManager::Instance()->AddComponent(graphicsComponent);
	newElement->SetGraphicsComponent(graphicsComponent);	
	
	newElement->mActive = true;
	
	
	PhysicsComponentInfo info;
	info.mIsStatic = true;
	info.mDoesNotSleep = false;
	info.mCollisionGroup = GRP_FIXED;
	info.mCollidesWith = GRP_BALL;	
	
	PhysicsComponent *cyl = PhysicsComponentFactory::BuildCylinder(extents.x(), kFixedHeight,initialPosition,info);
	
	PhysicsManager::Instance()->AddComponent( cyl  );
	newElement->SetPhysicsComponent( cyl );
	
	
	return newElement;
	
}

Entity *GameEntityFactory::BuildFXElement(  btVector3 &initialPosition, ExplodableComponent::ExplosionType effect)
{
	Entity *newElement = new Entity();
	newElement->SetPosition(initialPosition);
#if DEBUG
	newElement->mDebugName = "FXElement";
#endif
	
	FXGraphicsComponent *graphicsComponent = NULL;
	
	switch (effect) {
		case ExplodableComponent::EXPLODE_SMALL:
			//gfx
			graphicsComponent = 
				GraphicsComponentFactory::BuildFXElement(2, 2, @"ball.smokeExplode.sheet", 4,4,12, false);
			
			break;
		case ExplodableComponent::MUSHROOM:
			//gfx
			graphicsComponent = 
				GraphicsComponentFactory::BuildFXElement(2, 2, @"mushroom.sheet", 4,4,16, false);
			
			break;
		case ExplodableComponent::ELECTRO:
			//gfx
			graphicsComponent = 
				GraphicsComponentFactory::BuildFXElement(2, 2, @"ball.electric.sheet", 4,4,16, false);
			break;
		case ExplodableComponent::FREEZE:
			//gfx
			//graphicsComponent = 
			//	GraphicsComponentFactory::BuildFXElement(2, 2, @"ball.ice.sheet", 4,4,16, false);
			break;
		default:
			break;
	}
	
	// kick off default anim (won't do anything until the anim starts updating)
	//graphicsComponent->StartAnimation(AnimatedGraphicsComponent::IDLE );
	
	//GraphicsManager::Instance()->AddComponent(graphicsComponent);
	newElement->SetGraphicsComponent(graphicsComponent);	
	
		
	// target (for caching node id's)	
	newElement->mActive = true;
	
	return newElement;
	
}
