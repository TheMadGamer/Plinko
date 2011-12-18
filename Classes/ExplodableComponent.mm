/*
 *  ExplodabelComponent.mm
 *  Gopher
 *
 *  Created by Anthony Lobay on 4/13/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#import "Entity.h"
#import "ExplodableComponent.h"
#import "GraphicsComponent.h"
#import "GraphicsManager.h"
#import "PhysicsManager.h"
#import "PhysicsComponent.h"
#import "SceneManager.h"
#import "AudioDispatch.h"

#import <vector>

using namespace std;

namespace Dog3D
{

	void ExplodableComponent::Update(float dt)
	{
		if(mExplodeState == EXPLODE)
		{
			//btVector3 pos = mParent->GetPosition();
			//DLog(@"Explode posn %f %f %f", pos.x(), pos.y(), pos.z());
			
			mRespawnTime -= dt;
			
			if(mRespawnTime <=0)
			{
				mExplodeState = RECLAIM;
			}
			
		}
		
	}

	// generic ball
	void ExplodableComponent::OnCollision( Entity *collidesWith )
	{ 
		Explode();
		
		// get fx component				
		vector<Component *> fxComponents;
		mParent->FindComponentsOfType(FX, fxComponents);
		
		// disable
		for(int i = 0; i < fxComponents.size(); i++)
		{
			FXGraphicsComponent *fxComponent = static_cast<FXGraphicsComponent*>( fxComponents[i] );
			fxComponent->mActive = false;
			
		}
		
		btVector3 position = mParent->GetPosition();
		
		if(mExplosionType != ELECTRO && mExplosionType != FREEZE && mExplosionType != FIRE)
		{
			GraphicsManager::Instance()->ShowFXElement(position, mExplosionType);
		}
		
		AudioDispatch::Instance()->PlaySound(AudioDispatch::Boom2);
		
		// remove the physics component
		PhysicsComponent *physicsComponent =  mParent->GetPhysicsComponent();
		if(physicsComponent)
		{
			// remove ball from world
			physicsComponent->GetRigidBody()->setLinearVelocity(btVector3(0,0,0));
			physicsComponent->GetRigidBody()->setAngularVelocity(btVector3(0,0,0));
			PhysicsManager::Instance()->RemoveComponent(physicsComponent);
		}
		
		mParent->GetGraphicsComponent()->mActive = false;
		
	}
	
	void BumperExplodable::OnCollision( Entity *collidesWith )
	{
		if(mExplodeState == PRIMED)
		{
			Explode();
			const string flowerRed("flowerPurple");
			mParent->GetGraphicsComponent()->SetTexture(GraphicsManager::Instance()->GetTexture(&flowerRed));
		}
	}
	
	void ExplodableComponent::FinalAnimation(){}
	
	void BumperExplodable::FinalAnimation( )
	{ 
		btVector3 position = mParent->GetPosition();
		
		if(mExplosionType != ELECTRO && mExplosionType != FREEZE && mExplosionType != FIRE)
		{
			GraphicsManager::Instance()->ShowFXElement(position, mExplosionType);
		}
		
		AudioDispatch::Instance()->PlaySound(AudioDispatch::Boom2);
				
	}
	
	void PopExplodable::OnCollision( Entity *collidesWith)
	{
		if(mExplodeState == PRIMED)
		{
			Explode();
			const string flowerRed("flowerRed");
			mParent->GetGraphicsComponent()->SetTexture(GraphicsManager::Instance()->GetTexture(&flowerRed));
		}
	}
	
	void PopExplodable::FinalAnimation(  )
	{ 
		Explode();
		
		btVector3 position = mParent->GetPosition();
		
		if(mExplosionType != ELECTRO && mExplosionType != FREEZE && mExplosionType != FIRE)
		{
			GraphicsManager::Instance()->ShowFXElement(position, mExplosionType);
		}
		
		AudioDispatch::Instance()->PlaySound(AudioDispatch::Boom2);
		
		
		// remove the physics component
		PhysicsComponent *physicsComponent =  mParent->GetPhysicsComponent();
		if(physicsComponent)
		{
			// remove ball from world
			physicsComponent->GetRigidBody()->setLinearVelocity(btVector3(0,0,0));
			physicsComponent->GetRigidBody()->setAngularVelocity(btVector3(0,0,0));
			PhysicsManager::Instance()->RemoveComponent(physicsComponent);
			
			btVector3 extents =  mParent->GetGraphicsComponent()->GetScale();
			extents *= 0.5f;
			
			
			/*SceneManager::RespawnInfo *respawnInfo = new SceneManager::RespawnInfo(mRespawnType, 
																				   position, 
																				   extents, 
																				   0, 
																				   GamePlayManager::Instance()->GetLevelTime() + mRegenerateTime,
																				   mRegenerateTime);
			
			SceneManager::Instance()->AddDelayedSpawn(respawnInfo);*/
			 
			
			
		}
		
		mParent->GetGraphicsComponent()->mActive = false;
	}
	
	
}