/*
 *  ball.h
 *  Gopher
 *
 *  Created by Anthony Lobay on 1/19/10.
 *  Copyright 2010 3dDogStudios. All rights reserved.
 *
 */

#import <btBulletDynamicsCommon.h>
#import "Entity.h"

#import "SceneManager.h"
#import "ExplodableComponent.h"
#import "GraphicsManager.h"

#include <vector>
#import <string>

class GameEntityFactory
{
	
	
	public: 	
	
	static Dog3D::Entity *BuildBall( float radius,  btVector3 &initialPosition, 
									bool canRotate , float restitution, 
									float mass, Dog3D::ExplodableComponent::ExplosionType explosionType,
									float friction);
	
	static void BuildCannon( float radius, btVector3 &initialPosition , 
							std::vector<Dog3D::Entity *> &newEntities,
							float rotationOffset, float rotationScale,
							float powerScale);
	
	static Dog3D::Entity *BuildGround( btVector3 &initialPosition , 
									  float height, float width,
									  const std::string *backgroundTexture,
									  bool poolTable);

	static Dog3D::Entity *BuildTopPlate( btVector3 &initialPosition );
	

	// rock like collider
	static Dog3D::Entity *BuildTexturedCollider( btVector3 &initialPosition, btVector3 &halfExtents, 
												float yRotation, float restitution, 
												NSString *textureName, float graphicsScale);
	
	// rock collider
	static Dog3D::Entity *BuildCircularCollider( btVector3 &initialPosition, btVector3 &halfExtents, 
												float restitution, NSString *textureName, 
												float graphicsScale);
	
	// flower exploder
	static Dog3D::Entity *BuildCircularExploder( btVector3 &initialPosition, btVector3 &halfExtents, NSString *textureName, 
												float respawnTime, float graphicsScale, Dog3D::ExplodableComponent::ExplosionType explosionType);
	
	// boundary wall
	static Dog3D::Entity *BuildWall( btVector3 &initialPosition, btVector3 &halfExtents, float restitution );
	
	// build a static physics circle collider, no graphics component
	static Dog3D::Entity *BuildHedgeCircle( btVector3 &initialPosition, float radius );
	static Dog3D::Entity *BuildFenceBox( btVector3 &initialPosition, btVector3 &halfExtents );

	
	static Dog3D::Entity *BuildFXElement(  btVector3 &initialPosition, Dog3D::ExplodableComponent::ExplosionType elementType );
	
	static Dog3D::Entity *BuildFXElement(  btVector3 &initialPosition, btVector3 &extents, 
										 NSString *spriteSheet, int nTilesHigh, int nTilesWide, 
										 int nTiles,bool renderInPreQueue = false);

	static Dog3D::Entity *BuildFXCircularCollider(  btVector3 &initialPosition, btVector3 &extents, 
										 NSString *spriteSheet, int nTilesHigh, int nTilesWide, 
										 int nTiles);
	
	static Dog3D::Entity *BuildSprite( btVector3 &initialPosition, float w, float h, NSString *spriteName,  Dog3D::GraphicsManager::RenderQueueOrder order=Dog3D::GraphicsManager::MID);

	static Dog3D::Entity *BuildScreenSpaceSprite( btVector3 &initialPosition, float w, float h, NSString *spriteName, float duration);
	
};
