/*
 *  GamePlayManager.cpp
 *  Gopher
 *
 *  Created by Anthony Lobay on 2/1/10.
 *  Copyright 2010 3dDogStudios. All rights reserved.
 *
 */

#include "GamePlayManager.h"

#import <btBulletDynamicsCommon.h>
#import <vector>
#import <algorithm>
#import <set>

#import "TriggerComponent.h"
#import "ExplodableComponent.h"
#import "GamePlayManager.h"
#import "Entity.h"
#import "NodeNetwork.h"
#import "GraphicsComponent.h"
#import "GraphicsManager.h"

#import "PhysicsManager.h"
#import "PhysicsComponentFactory.h"
#import "TargetComponent.h"
#import "SceneManager.h"

using namespace std;

const float kTapForce = 30.0;


namespace Dog3D
{
	typedef vector<TriggerComponent*>::iterator  TriggerComponentIterator; 
	
	typedef list<Entity *>::iterator EntityListIterator;
	
#pragma mark INIT AND CTOR	
	
	GamePlayManager * GamePlayManager::sGamePlayManager;
	
	void GamePlayManager::Initialize()
	{
		sGamePlayManager = new GamePlayManager();
		srand(2);	
	}
	
	void GamePlayManager::Unload()
	{
				
		mTargets.clear();
		
		mBalls.clear();
		
		
		mSpawnComponents.clear();
		
#ifdef BUILD_PADDLE_MODE
		mPaddles.clear();
		mFlippers.clear();
#endif
		
		mExplodables.clear();
		
		mSpawnIntervals.clear();
		
		mGopherHUD = NULL;
		mCarrotHUD = NULL;
		
		mLevelTime = 0;
		
		mCannonController = NULL;
		mCannonUI = NULL;
		
#if DEBUG
		if(mDebugVertices)
		{
			delete [] mDebugVertices;
		}
#endif
		
	}
	
#if DEBUG
	void GamePlayManager::DrawDebugLines()
	{
		return;
		
		UpdateDebugVertices();
		
		glEnableClientState(GL_VERTEX_ARRAY);
		
		// MATERIAL
		glDisableClientState(GL_COLOR_ARRAY);
		glColor4f(1,1,1,1);
		
		for(int i = 0; i < mNumDebugVertices; i+=2)
		{			// To-Do: add support for creating and holding a display list
			glVertexPointer(3, GL_FLOAT, 0, mDebugVertices+i);
			glDrawArrays(GL_LINE_STRIP, 0, 2);
			
		}
	}
#endif
	
	
		
#pragma mark UPDATE
	void GamePlayManager::Update(float deltaTime)
	{
		
				
		if(mGameState == GOPHER_WIN || mGameState == GOPHER_LOST)
		{

			for(EntityListIterator it = mBalls.begin(); it!= mBalls.end(); it++)
			{
				(*it)->mActive = false;
			}
			
			
		}
		else
		{
			// added to keep the ball in the xz plane
			ClampVelocity();
			
			// compute positions
			// eat veggies - todo move this up to update carrot eating
			UpdateControllers(deltaTime);
			
			
			// spawn or spawn new balls
			bool ballDied = ReclaimBalls(deltaTime);
			
			if(ballDied)
			{
				// if ball impacts a flower, on collide
				UpdateObjectContacts(deltaTime);	
			}
			
		}
			
		// TODO update game state
		mGameState = PLAY;
		
		
		mLevelTime+= deltaTime;
	}	
	
	// spawns in ball at a new location
	void GamePlayManager::ClampVelocity()
	{
		for(list<Entity *>::iterator it = mBalls.begin(); it != mBalls.end(); it++ )
		{
			Entity *entity = (*it);
			if( entity->mActive)
			{
				PhysicsComponent *physics = entity->GetPhysicsComponent();
				physics->GetRigidBody()->setAngularVelocity(btVector3(0,0,0));
				
				btVector3 ballLinear = physics->GetRigidBody()->getLinearVelocity();
				ballLinear.setY(0);
				physics->GetRigidBody()->setLinearVelocity(ballLinear);
															
			}
		}
	}

	
	// spawns in ball at a new location
	bool GamePlayManager::ReclaimBalls(float dt)
	{
		bool reclaimed = false;
		for(list<Entity *>::iterator it = mBalls.begin(); it != mBalls.end(); it++ )
		{
			Entity *entity = (*it);
			if( entity->mActive)
			{
				btVector3 position = entity->GetPosition();	
				ExplodableComponent *explodable =  entity->GetExplodable();	
				
#if DEBUG
				PhysicsComponent *physics = entity->GetPhysicsComponent();
				if(physics->GetRigidBody()->getLinearVelocity().getY() != 0)
				{
					DLog(@"Y Fail");
				}
#endif		
				// if ball is in a RECLAIM state
				// or its out of bounds, reclaim
				if ( (explodable && explodable->CanReclaim()) ||
					(fabs(position.getX()) > (mWorldBounds.x() + 5) || 
					 position.getY() < -5 || 
					 fabs(position.getZ()) > (mWorldBounds.z() + 5) ||
					 position.getY() > 20))
				{
					PhysicsManager::Instance()->RemoveComponent(entity->GetPhysicsComponent());
					
					ReclaimBall(entity);
					//toRemove.push_back(entity);
					if(mCannonController)
					{
#if DEBUG
						DLog(@"Removing Ball %s", (*it)->mDebugName.c_str());
#endif
						it = mBalls.erase(it);
						reclaimed=  true;
					}
				}
			}
		}
		
		return reclaimed;
	}
	
	// either respawns ball or adds to cannon
	void GamePlayManager::ReclaimBall(Entity *ball)
	{
		
		ExplodableComponent *explodable = ball->GetExplodable();
		
		// reset the explodable into idle state
		explodable->Reset();
		
		if(mCannonController )
		{
			// get the physics component
			PhysicsComponent *physicsComponent =  ball->GetPhysicsComponent();
			physicsComponent->SetKinematic(true);
			ball->mActive = false;
			if(mUnlimitedBalls)
			{
				// adds to physics world
				mCannonController->AddBall(ball);
			}
		}
		else
		{
			// adds back to physics world
			// continuous spawn
			SpawnBall(ball);
		}
	}
	
	// for touch/flick/tilt mode only
	// adds ball back to physics world
	void GamePlayManager::SpawnBall(Entity *ball, int position)
	{
		DLog(@"Spawining ball");
		
		ExplodableComponent *explodable = ball->GetExplodable();
		
		// only in flick mode do we defer activation

		explodable->Prime();
		
		// pick a random start point (see rands below)
		btVector3 resetPosition(mBallSpawn);
		mBallSpawn.setY(1.5);
		
		

		// re activate gfx
		ball->GetGraphicsComponent()->mActive = true;
		
		// get fx component				
		vector<Component *> fxComponents;
		ball->FindComponentsOfType(FX, fxComponents);
		
		// disable
		for(int i = 0; i < fxComponents.size(); i++)
		{
			FXGraphicsComponent *fxComponent = static_cast<FXGraphicsComponent*>( fxComponents[i] );
			fxComponent->mActive = true;
		}
		
		
		// form a transform to respawn at
		btTransform transform;
		transform.setIdentity();
		transform.setOrigin(resetPosition);
		
		// get the physics component
		PhysicsComponent *physicsComponent = ball->GetPhysicsComponent();
		
		if(physicsComponent)
		{
			// get the rigid body
			btRigidBody *rigidBody = physicsComponent->GetRigidBody();
			
			if(rigidBody)
			{
				// update the rigid body transform
				rigidBody->setWorldTransform(transform);
				
				btVector3 zero(0,0,0);
				rigidBody->setLinearVelocity(zero);
				rigidBody->setAngularVelocity(zero);
				
			}
			
			PhysicsManager::Instance()->AddComponent(physicsComponent);
			
			
			physicsComponent->SetKinematic(false);
			
		}
		// set the parent object's position
		ball->SetPosition(resetPosition);
		
		
	}
	
	
	// check ball/gopher collisions for explode
	void GamePlayManager::UpdateObjectContacts(float dt)
	{

		set<Entity *> triggeredObjects;
		
		PhysicsManager::Instance()->GetTriggerContactList(triggeredObjects);
		
		for(set<Entity*>::iterator it = triggeredObjects.begin(); it != triggeredObjects.end(); it++)
		{
			ExplodableComponent *explodable = (*it)->GetExplodable();
			if(explodable)
			{
				explodable->FinalAnimation();
			}
		}
	}
	
	// updates ball (explode) and gopher controllers
	void GamePlayManager::UpdateControllers(float dt)
	{
		for(EntityListIterator it = mBalls.begin(); it != mBalls.end(); it++)
		{
			ExplodableComponent *explodable = (*it)->GetExplodable();
			explodable->Update(dt);
		}
		
		
		for( list<ExplodableComponent *>::iterator it = mExplodables.begin(); it != mExplodables.end(); it++)
		{
			ExplodableComponent *explodable = (*it);
			if(explodable->CanReclaim())
			{
#if DEBUG
				DLog(@"Removing Explodable %s",explodable->GetParent()->mDebugName.c_str());
#endif
				it = mExplodables.erase(it);
				
			}
			else {
				explodable->Update(dt);
			}
		}
	}
	
	
}