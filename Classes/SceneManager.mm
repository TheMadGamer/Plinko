/*
 *  SceneManager.mm
 *  Gopher
 *
 *  Created by Anthony Lobay on 3/2/10.
 *  Copyright 2010 HighlandAvenue. All rights reserved.
 *
 */

#include "SceneManager.h"

#import <btBulletDynamicsCommon.h>

#import "GameEntityFactory.h"
#import "PhysicsComponentFactory.h"

#import "PhysicsManager.h"
#import "GraphicsManager.h"
#import "GamePlayManager.h"
#import "SceneManager.h"

#import "TriggerComponent.h"

#import "AudioDispatch.h"

const float kBallRadius = 0.5;

const float kWallHeight = 2.5;
const float kBoxHeight = 1.5;

const float kWallSlop = 0.5;

const float kGoalOffset = 1.1;

using namespace Dog3D;
using namespace std;

SceneManager *SceneManager::sInstance;

SceneManager::LevelControlInfo::LevelControlInfo(NSDictionary *controlDictionary)
{
	DLog(@"Init level control");
	mNumCombos = [[controlDictionary objectForKey:@"NumCombos"] intValue];
	mNumGopherLives = [[controlDictionary objectForKey:@"NumGopherLives"] intValue];	
	//mNumCarrotLives = [[controlDictionary objectForKey:@"NumCarrotLives"] intValue];
	
	NSString *background = [controlDictionary objectForKey:@"Background"];
	mBackground = [background UTF8String];
	
	mScoreMode = [[controlDictionary objectForKey:@"ScoreMode"] intValue];	
	
	mBallTypes = [[controlDictionary objectForKey:@"BallTypes"] intValue];
	if(mBallTypes == 0)
	{
		mBallTypes = -1;
	}
	
	// -1 inf
	mNumBalls = [[controlDictionary objectForKey:@"NumBalls"] intValue];
	if(mNumBalls == 0)
	{
		mNumBalls = -1;
	}
	
	
	DLog(@"Control NumCombos:%d GopherLives:%d ", 
		  mNumCombos, mNumGopherLives );
	
	DLog(@"Control ScoreMode:%d BallTypes%d NumBalls:%d",
		   mScoreMode, mBallTypes, mNumBalls);
	
	mCollisionAvoidance = [[controlDictionary objectForKey:@"CollisionAvoidance"] intValue];
	
	NSArray *spawnIntervalArray = [controlDictionary objectForKey:@"SpawnIntervals"];
	[spawnIntervalArray retain];
	if(spawnIntervalArray != nil)
	{
		for( NSUInteger i = 0; i < [spawnIntervalArray count]; i++)
		{
			NSDictionary *pairDict = [spawnIntervalArray objectAtIndex:i];
			std::pair<float, int> p;
			p.first = [[pairDict objectForKey:@"Time"] floatValue];
			p.second = [[pairDict objectForKey:@"Gophers"] intValue];
			DLog(@"Loading Spawn Interval %f %d", p.first, p.second);
			
			mSpawnIntervals.push_back(p);
		}
	}
	[spawnIntervalArray release];
	
	float xBound = [[controlDictionary objectForKey:@"XBounds"] floatValue];
	if(xBound > 0)
	{
		mWorldBounds.setX(xBound);
		DLog(@"XBound %f", xBound);
	}
	else {
		// default
		mWorldBounds.setX(10);
	}

	mWorldBounds.setY(4);
	
	float zBound = [[controlDictionary objectForKey:@"ZBounds"] floatValue];
	if(zBound > 0)
	{
		mWorldBounds.setZ(zBound);
		DLog(@"ZBound %f", zBound);
	}
	else {
		mWorldBounds.setZ(15);
	}
	
	float ballX = [[controlDictionary objectForKey:@"BallSpawnX"] floatValue];
	mBallSpawn.setX(ballX);
	
	mBallSpawn.setY(1.5);
	
	float ballZ = [[controlDictionary objectForKey:@"BallSpawnZ"] floatValue];
	mBallSpawn.setZ(ballZ);
	
	
	float dist = [[controlDictionary objectForKey:@"CarrotSearchDistance"] floatValue];	
	if(dist > 0)
	{
		mCarrotSearchDistance = dist;
	}
	else {
		mCarrotSearchDistance = 20.0f;
	}

	
	DLog(@"Finish Init Level Control");
}




void SceneManager::LoadScene( NSString *levelName)
{
	if(mSceneLoaded)
	{
		DLog(@"Unloading Scene");
		UnloadScene();
		DLog(@"Done");
	}
		
	DLog(@" **** Loading Scene **** ");
	PhysicsManager::Instance()->CreateWorld();
	
	// create a pointer to a dictionary and
	// read ".plist" from application bundle
	
	NSString *path = [[NSBundle mainBundle] bundlePath];
	NSString *finalPath = [path stringByAppendingPathComponent:levelName];
	
	NSDictionary *rootDictionary = [[NSDictionary dictionaryWithContentsOfFile:finalPath] retain];
	NSDictionary *controlDictionary = [[rootDictionary objectForKey:@"LevelControl"] retain];
	
	mLevelControl = LevelControlInfo(controlDictionary);
	mNumCarrots = 0;
	
	GamePlayManager::Instance()->SetUnlimitedBalls(0);
	
	
	GamePlayManager::Instance()->SetBallSpawn(mLevelControl.mBallSpawn);

	// todo remove z component
	//btVector3 gravity(12,-12,0);
	//PhysicsManager::Instance()->SetGravity(gravity);
			
	
	btVector3 position(0,0,0);
	
	for(int i = 0; i < 100; i++)
	{
		Entity *entity = GameEntityFactory::BuildFXElement(position, ExplodableComponent::MUSHROOM);
		mFXPool.push(entity);
	}
	
	GamePlayManager::Instance()->SetWorldBounds(mLevelControl.mWorldBounds);
	
	GraphicsManager::Instance()->SetFXPool(&mFXPool);
	
	
	// create static world walls
	{
		int wallFlags = SceneManager::FLOOR | SceneManager::TOP | SceneManager::BOTTOM;
		DLog(@"Wall flags %d", wallFlags);
		CreateWalls( &mLevelControl.mBackground , wallFlags , false );
	}
	
	LoadSceneObjects(rootDictionary);
		
	LoadGeneratedObjects(rootDictionary  );	
	
	
	LoadHUDs();
	
	// finally set number of carrot and gophers
	GamePlayManager::Instance()->InitializeLevel(mLevelControl.mNumGopherLives, mNumCarrots);
	
	// anything that would go in front would be added here.
	mSceneLoaded = true;
	mSceneName = [levelName UTF8String];
	
	[controlDictionary release];
	[rootDictionary release];
	
	
	DLog(@"**** Done loading scene ****");
	
}

void SceneManager::LoadSceneObjects(NSDictionary *rootDictionary)
{
	NSDictionary *layoutDictionary = [rootDictionary objectForKey:@"LayoutObjects"];
	
	// load up things like spawn points, targets, hedges
	for (id key in layoutDictionary) 
	{
		NSDictionary *object = [layoutDictionary objectForKey:key];
		
		NSString *type = [object objectForKey:@"type"];
		
		float x = [[object objectForKey:@"x"] floatValue];
		float y = [[object objectForKey:@"y"] floatValue];
		float z = [[object objectForKey:@"z"] floatValue];
		btVector3 pos( x,y,z);
		
		
		float sx = [[object objectForKey:@"sx"] floatValue];
		float sy = [[object objectForKey:@"sy"] floatValue];
		float sz = [[object objectForKey:@"sz"] floatValue];
		
		btVector3 extents(sx, sy, sz);
		
		float radius = [[object objectForKey:@"radius"] floatValue];
		
		float rotationY = [[object objectForKey:@"ry"] floatValue];
		
		float spawnTime = [[object objectForKey:@"spawnTime"] floatValue];
		
		NSRange flowerSubRange = [type rangeOfString:@"flower"];
		
	
		if ([type isEqualToString:@"hedgeCollider"]  )
		{
			
			mHedges.push_back( GameEntityFactory::BuildHedgeCircle(pos, radius) );
		}	
		// test box
		else if ([type isEqualToString:@"fenceCollider"] )
		{		
			btVector3 extents(sx, 10, sz);
			
			//hedges, fences are deallocated the same way
			mHedges.push_back( GameEntityFactory::BuildFenceBox(pos, extents) );
		
		}
		else if([type isEqualToString:@"fenceLt"] || [type isEqualToString:@"fenceC"] || [type isEqualToString:@"hedge1"])
		{
			DLog(@"Loading collider %@ with YRotation %f", type, rotationY);
			
			Entity * item = GameEntityFactory::BuildTexturedCollider(pos, extents, rotationY, mFixedRest, type, 1.33f);
			mSceneElements.insert(item);
			
			item->SetYRotation(rotationY);
		}
		else if([type isEqualToString:@"rock"] )
		{
			// no delayed rock spawning
			/*if(spawnTime > 0)
			{
				mDelayedSpawns.push_back(new SpawnInfo([type UTF8String], pos, extents, 0, spawnTime));
			}
			else*/
			{
				// rocks have a 25% padding
				Entity * item = GameEntityFactory::BuildCircularCollider(pos, extents, mFixedRest , type, 1.33f);
				mSceneElements.insert(item);
			}
		}
		else if([type isEqualToString:@"bounceRock"]  )
		{
				// rocks have a 25% padding
				Entity * item = GameEntityFactory::BuildCircularCollider(pos, extents, mBounceRest, @"rock", 1.33f);
				mSceneElements.insert(item);
		
		}
		else if([type isEqualToString:@"flower"])
		{
			Entity *item = GameEntityFactory::BuildCircularExploder(pos, extents, @"flower", spawnTime,1, ExplodableComponent::EXPLODE_SMALL);
			mSceneElements.insert(item);
			item->GetExplodable()->Prime();
		}
		else if( flowerSubRange.location != NSNotFound)
		{
			NSString *subType = [[NSString alloc] initWithString:[type substringFromIndex:6]];
			DLog(@"Type Name %@", subType);
			
			Entity *item = NULL;
			
			if([type isEqualToString:@"flowerPurple"])
			{			
				item = GameEntityFactory::BuildCircularExploder(pos, extents, type, spawnTime,1,
														ExplodableComponent::BUMPER );
			}
			else {
				
#warning "Temp hack to produce purple and blue balls"
				if(rand() %7)
				{
					item = GameEntityFactory::BuildCircularExploder(pos, extents, @"flowerPurple", spawnTime,1,
																ExplodableComponent::POP );					
				}
				else {
					
					item = GameEntityFactory::BuildCircularExploder(pos, extents, @"flowerBlue", spawnTime,1,
														 ExplodableComponent::POP );				
				}
			}

			
			mSceneElements.insert(item);
			item->GetExplodable()->Prime();
			
			[subType release];
		}
		else if([type isEqualToString:@"firePit"] )
		{
			// fx renders in pre queue
			Entity * firePit = GameEntityFactory::BuildFXElement(pos, extents,
														   @"tiki.sheet", 2,2,4, true);
			
			mSceneElements.insert(firePit);
			
		}
		else if([type isEqualToString:@"uFO"] )
		{
			
			Entity * element = GameEntityFactory::BuildFXElement(pos, extents,
																 @"UFO.sheet", 2,2,4);
			
			mSceneElements.insert(element);
			
		}
		else if([type isEqualToString:@"fountain"] )
		{
			Entity * element = GameEntityFactory::BuildFXCircularCollider(pos, extents,
																 @"fountain.sheet", 2,2,4);
			
			mSceneElements.insert(element);
			
		}
		else {
			DLog(@"--->>> Error loading object of type %@", type);
		}

	}

}

// spawn in objects
void SceneManager::LoadGeneratedObjects(NSDictionary *rootDictionary)
{
	int poolBallCount = 0;
	
	NSDictionary *levelDictionary = [rootDictionary objectForKey:@"GeneratedObjects"];
	// load up generated gophers and balls
	
	for (id key in levelDictionary) 
	{
		NSDictionary *object = [levelDictionary objectForKey:key];
		
		NSString *type = [object objectForKey:@"type"];
		
		if([type compare:@"cannon"] == NSOrderedSame )
		{
			
			float scale = [[object objectForKey:@"scale"] floatValue];
			
			//btVector3 pos( 8, 1.5, 0);
			float x = [[object objectForKey:@"x"] floatValue];
			//float y = [[object objectForKey:@"y"] floatValue];
			float z = [[object objectForKey:@"z"] floatValue];
			btVector3 pos( x,1.5,z);
			
			float rotationOffset = [[object objectForKey:@"rotationOffset"] floatValue];
			
			float cannonPowerScale = [[object objectForKey:@"powerScale"] floatValue];
			if(cannonPowerScale == 0)
			{
				cannonPowerScale = 1;
			}
			
			float rotationScale =  M_PI/1.8f;
			
			scale *= 4.0f;
			
			// can roll if not in paddle mode
			vector<Entity*> newObjects;
			GameEntityFactory::BuildCannon(scale, pos, newObjects, rotationOffset, rotationScale, cannonPowerScale);
			
			mCannon = newObjects[0];
			mHuds.push_back(newObjects[1]);
			mHuds.push_back(newObjects[2]);
			mHuds.push_back(newObjects[3]);
			
			GraphicsManager::Instance()->AddComponent( mCannon->GetGraphicsComponent(), GraphicsManager::POST ); 
			
			CannonController *controller = dynamic_cast<CannonController*>( mCannon->GetController());
			
			// create 50 balls, add to cannon
			int numBalls = ( mLevelControl.mNumBalls == -1) ? 20 :  mLevelControl.mNumBalls;
			
			for(int i = 0; i <numBalls ; i++)
			{
				
				float radius = scale * 0.125f * 0.75f;
				
				int randType = 1; //EXPLODE_SMALL
				
				if(mLevelControl.mBallTypes == 1 || 
				   mLevelControl.mBallTypes == 2 || 
				   mLevelControl.mBallTypes == 4 ||
				   mLevelControl.mBallTypes == 8 ||
				   mLevelControl.mBallTypes == 16)
				{
					randType = mLevelControl.mBallTypes;
				}
				else {
					
					// pick a random ball type
					while(true)
					{
						randType = 1 << (rand() % 5);
						if(randType & mLevelControl.mBallTypes)
						{
							break;
						}
					}
				}
				
				//ExplodableComponent::ExplosionType randType = ExplodableComponent::EXPLODE_SMALL;
				// can roll if not in paddle mode
				// in the case of ricochet, anti-gopher ball that doesn't detonate itself, only the goph
				Entity *ball = GameEntityFactory::BuildBall(radius, pos, true ,
															0.8f,
															1.0f,  
															(ExplodableComponent::ExplosionType) randType, 
															0.5f);
				mBalls.push_back(ball);
				
				ball->mActive = false;
				
				PhysicsComponent *physicsComponent = dynamic_cast<PhysicsComponent*>(ball->GetPhysicsComponent());
				physicsComponent->SetKinematic(true);
				controller->AddBall(ball);

				GraphicsManager::Instance()->AddComponent(ball->GetGraphicsComponent(), GraphicsManager::POST);

				
			}
		}
	}
	
	if( mBalls.size() == 0)
	{
		DLog(@"No balls loaded - fail");
	}
	
}

void SceneManager::LoadHUDs()
{

	{
		btVector3 position( -9, 1, -14);
		
		Entity *hud = GameEntityFactory::BuildScreenSpaceSprite(position, 2.0f, 2.0f, 
														 @"PauseButton", HUGE_VAL);
		
		// pause btn does not rotate
		static_cast<ScreenSpaceComponent*>(hud->GetGraphicsComponent())->mRotateTowardsTarget = false;
		static_cast<ScreenSpaceComponent*>(hud->GetGraphicsComponent())->mConstrainToCircle = false;
		
		// do not add to huds - Graphics Manager will clean this up
	}
	
	
	/*
	{
		btVector3 position( 0,1,0);
		btVector3 extent(3, 1, 1);
		
		Entity *hud = GameEntityFactory::BuildText(position, extent.x(), extent.z(), @"ABCDcore: 123");
		mHuds.push_back(hud);
		

	}*/
	
}

void SceneManager::ConvertToSingleBodies(Entity *compoundEntity, vector<Entity*> &newBodies)
{
	CompoundGraphicsComponent *graphicsParent = dynamic_cast<CompoundGraphicsComponent*>(compoundEntity->GetGraphicsComponent());		
	PhysicsComponent *physicsParent =  compoundEntity->GetPhysicsComponent();
	
	if(physicsParent && graphicsParent)
	{
		// toss the physics object
		btRigidBody *body = physicsParent->GetRigidBody();
		PhysicsManager::Instance()->RemoveComponent(physicsParent);
		GraphicsManager::Instance()->RemoveComponent(graphicsParent);
		
		while(!graphicsParent->IsEmtpy())
		{
			GraphicsComponent *gfxChild = graphicsParent->RemoveFirstChild();
			
			
			btVector3 initialPosition = compoundEntity->GetPosition();
			initialPosition += gfxChild->GetOffset();
			
			btVector3 halfExtents = gfxChild->GetScale();
			halfExtents *= 0.5;		
			
			PhysicsComponentInfo info;
			info.mIsStatic = false;
			info.mCanRotate = true;
			info.mRestitution = body->getRestitution();
			info.mMass =  1.0f/body->getInvMass();
			info.mDoesNotSleep = true;
			
			PhysicsComponent *physics = 
				PhysicsComponentFactory::BuildBox(
							initialPosition, halfExtents, 0, info);
			
			Entity *newEntity = new Entity();
#if DEBUG
			newEntity->mDebugName = "Destruction Child";
#endif
			
			newEntity->SetPosition(initialPosition);
			newEntity->SetGraphicsComponent(gfxChild);
			GraphicsManager::Instance()->AddComponent(gfxChild);
			
			PhysicsManager::Instance()->AddComponent(physics);
			newEntity->SetPhysicsComponent(physics);
			
			ExplodableComponent *finalExplodable = new ExplodableComponent(ExplodableComponent::EXPLODE_SMALL);
			newEntity->SetExplodable(finalExplodable);
			
			// and add to stuff to be removed later
			mSceneElements.insert(newEntity);
			
			newBodies.push_back(newEntity);
		}
		
		compoundEntity->mActive = false;
		
	}
	else 
	{
		DLog(@"Massive failure with Compound Explodable");
		GraphicsManager::Instance()->RemoveComponent(compoundEntity->GetGraphicsComponent());
		
		if(physicsParent)
		{
			PhysicsManager::Instance()->RemoveComponent(physicsParent);
		}	
			
		// wait for later for Sceme Mgr to delete
		compoundEntity->mActive = false;
		
	}
}


void SceneManager::UnloadScene()
{
	DLog(@" **** Unloading Scene **** ");
	
	PhysicsManager::Instance()->Unload();
	GamePlayManager::Instance()->Unload();
	GraphicsManager::Instance()->Unload();
	
	// try to evict the level control background texture
	//GraphicsManager::Instance()->EvictTexture(mLevelControl.mBackground);
	
	for(EntityIterator it = mSpawnPoints.begin(); it!= mSpawnPoints.end(); it++)
	{
		delete *it;
	}
	mSpawnPoints.clear();	
	
	for(EntityIterator it = mTargets.begin(); it!= mTargets.end(); it++)
	{
		delete *it;
	}
	mTargets.clear();
	
	for(EntityIterator it = mGophers.begin(); it!= mGophers.end(); it++)
	{
		delete *it;
	}
	mGophers.clear();
	
	
	for(EntityIterator it = mHedges.begin(); it!= mHedges.end(); it++)
	{
		delete *it;
	}
	mHedges.clear();
	
	
	for(EntityIterator it = mWalls.begin(); it!= mWalls.end(); it++)
	{
		delete *it;
	}
	mWalls.clear();
	
	
	for(EntityIterator it = mBalls.begin(); it!= mBalls.end(); it++)
	{
		delete *it;
	}
	mBalls.clear();
	
	
	for(EntityIterator it = mHuds.begin(); it!= mHuds.end(); it++)
	{
		delete *it;
	}
	mHuds.clear();
	
	// this is a set
	for(set<Entity*>::iterator it = mSceneElements.begin(); it != mSceneElements.end(); it++)
	{
		delete *it;
	}
	mSceneElements.clear();
	
	while (!mDelayedSpawns.empty()) 
	{
		delete mDelayedSpawns.front();
		mDelayedSpawns.pop_front();
	}
	mDelayedSpawns.clear();
	
	// TODO - pool these
	while(!mFXPool.empty())
	{
		Entity *ent = mFXPool.front();
		delete (ent);
		mFXPool.pop();
	}
	
	delete mCannon;
	mCannon = NULL;
	
	mSceneLoaded = false;

}

	
void SceneManager::CreateWalls( const string *backgroundTexture, int wallFlags, bool poolTable)
{	
	
	float kEpsilon = 0.5;
	
	const float wallRestitution = 0.9f;
	
	// create ground 
	if(wallFlags & FLOOR) {
		btVector3 pos(0,0,0);
		
		//mWalls.push_back(GameEntityFactory::BuildGround(pos, mLevelControl.mWorldBounds.x() *2.0f, 
		//												mLevelControl.mWorldBounds.z() *2.0f, 
		//												backgroundTexture, poolTable));
		
	}
	
	// create top plate
	if(wallFlags & CEILING) {
		btVector3 pos(0,kWallHeight+2.0,0);
		
		mWalls.push_back(GameEntityFactory::BuildTopPlate(pos));
	}
	
	// catching objects off screen, then re-spawning
	//left wall
	if(wallFlags & LEFT) {
		btVector3 pos( -mLevelControl.mWorldBounds.x() - kEpsilon, kWallHeight, 0);
		btVector3 extents(kEpsilon,kWallHeight, mLevelControl.mWorldBounds.z() + kEpsilon );
		mWalls.push_back( GameEntityFactory::BuildWall(pos, extents, wallRestitution ) );
	}
	
	//right wall
	if(wallFlags & RIGHT) {
		btVector3 pos(mLevelControl.mWorldBounds.x() + kEpsilon, kWallHeight, 0);
		btVector3 extents(kEpsilon,kWallHeight, mLevelControl.mWorldBounds.z()  + kEpsilon );
		mWalls.push_back( GameEntityFactory::BuildWall(pos, extents, wallRestitution ) );
	}
	
	
	//top wall
	if(wallFlags & TOP) {
		btVector3 pos( 0, kWallHeight, mLevelControl.mWorldBounds.z() + kEpsilon );
		btVector3 extents(mLevelControl.mWorldBounds.x()+ kEpsilon , kWallHeight, kEpsilon);
		mWalls.push_back( GameEntityFactory::BuildWall(pos, extents, wallRestitution ) );
	}
	
	//bottom wall
	if(wallFlags & BOTTOM) {
		btVector3 pos( 0, kWallHeight, -mLevelControl.mWorldBounds.z() - kEpsilon  );
		btVector3 extents(mLevelControl.mWorldBounds.x()+ kEpsilon , kWallHeight, kEpsilon);
		mWalls.push_back( GameEntityFactory::BuildWall(pos, extents, wallRestitution ) );
	}
	
}

// this handles spawn and respawn
void SceneManager::Update(float dt)
{

	
	for(list<SpawnInfo *>::iterator it = mDelayedSpawns.begin(); it != mDelayedSpawns.end(); it++  ) 
	{
		SpawnInfo *info = *it;
		if( info->mSpawnTime <= GamePlayManager::Instance()->GetLevelTime())
		{
			Entity * item = NULL;
			//spawn
			
			
			
			if(info->mTypeName == "rock")
			{
				
				DLog(@"Spawn Rock");
				item = GameEntityFactory::BuildCircularCollider(
												info->mPosition, 
												info->mScale, 
												0.45f,  
												@"rock", 
												1.33f);
				
				mSceneElements.insert(item);
				
				//GraphicsManager::Instance()->ShowFXElement(info->mPosition, ExplodableComponent::FREEZE);
				
				delete info;
				
				it = mDelayedSpawns.erase(it);
			}
			else if(info->mTypeName == "flower")
			{
				
				DLog(@"Spawn Flower");
				
				RespawnInfo *respawnInfo = (RespawnInfo*)(info);
				DLog(@" Scn: Respawn Info %f", respawnInfo->mRespawnInterval);
				
				item = GameEntityFactory::BuildCircularExploder(info->mPosition, 
																info->mScale, 
																@"flower", 
																respawnInfo->mRespawnInterval, 1, ExplodableComponent::EXPLODE_SMALL) ;
			
			
				GraphicsComponent *graphics= item->GetGraphicsComponent();
				graphics->mActive = false;
				
				mSceneElements.insert(item);
				
				GraphicsManager::Instance()->ShowFXElement(info->mPosition, @"flower.sheet", graphics, info->mScale.x());
				
				delete info;
				
				it = mDelayedSpawns.erase(it);
				
			}
			else if( info->mTypeName.find("flower") != string::npos)
			{
				//NSString *subType = [[NSString alloc] initWithString:[type substringFromIndex:6]];
				//DLog(@"Type Name %@", subType);
				
				RespawnInfo *respawnInfo = (RespawnInfo*)(info);
				DLog(@" Scn: Respawn Info %f", respawnInfo->mRespawnInterval);
				
				Entity *item = GameEntityFactory::BuildCircularExploder(info->mPosition, 
																		info->mScale, 
																		[[NSString alloc] initWithUTF8String:info->mTypeName.c_str()], 
																		respawnInfo->mRespawnInterval, 1,
																		ExplodableComponent::POP);
				
				
				GraphicsComponent *graphics= item->GetGraphicsComponent();
				graphics->mActive = false;
				
				mSceneElements.insert(item);
				
				//NSString *baseName =  [[NSString alloc] initWithUTF8String:info->mTypeName.c_str()];
				//NSString *sheetName = [baseName stringByAppendingString:@".sheet"];
				
				GraphicsManager::Instance()->ShowFXElement(info->mPosition, @"flowerPurple.sheet", graphics, info->mScale.x());
				
				//[baseName release];
 				//[sheetName autorelease];
				
				
				delete info;
				
				it = mDelayedSpawns.erase(it);				
				
			}
			
			else {
				DLog(@"Don't know how to spawn %@", [[NSString alloc] initWithUTF8String:info->mTypeName.c_str()]);
			}

			
		}
		
	}
	
	
}

