/*
 *  Explodable.h
 *  Gopher
 *
 *  Created by Anthony Lobay on 2/24/10.
 *  Copyright 2010 3dDogStudios. All rights reserved.
 *
 */


#import <vector>
#import <string>
#import "Component.h"
#import "NodeNetwork.h"
#import "GraphicsComponent.h"

namespace Dog3D 
{
	
	const float kBallRespawnTime = 1.1;
	
	
	/// Ball exploder component
	class ExplodableComponent : public Component
	{	
	public:
		
		enum ExplodeState 
		{
			//IDLE, do nothing
			//PRIMED, begin count down
			IDLE, PRIMED, EXPLODE, RECLAIM
		};
		
		enum ExplosionType
		{
			EXPLODE_SMALL = 1, 
			ELECTRO = 2, 
			FREEZE = 4,
			FIRE = 8,
			MUSHROOM = 16,
			CUE_BALL = 32,
			BALL_8 = 64,
			POP = 128,
			BUMPER = 256
		};
		
	private:
		float mRespawnTime;
		
	protected:
		ExplodeState mExplodeState;
		
		
		float mFuseTime;
		
		ExplosionType mExplosionType;
		
		void Explode()
		{
			mExplodeState = EXPLODE;
			mRespawnTime = kBallRespawnTime;
		}
		
	public:
		
		ExplodableComponent( ExplosionType explosionType ) : 
		mExplodeState(IDLE), 
		mRespawnTime(0), 
		mExplosionType(explosionType)
		{
			mTypeId = LOGIC_EXPLODE;
		};
		
		
		inline ExplosionType GetExplosionType(){ return mExplosionType;}
		
		inline bool IsExploding() { return mExplodeState == EXPLODE; }
		inline bool IsPrimed() { return mExplodeState == PRIMED;}
		inline bool CanReclaim() { return mExplodeState == RECLAIM;}
		
		// kick off explode
		virtual void OnCollision(Entity *collidesWith);
		
		virtual void FinalAnimation();
		
		// update explode timer
		void Update(float dt);

		
		// this allows defered activation in flick mode
		// the ball can idle unit touched
		inline void Prime()
		{
			mExplodeState = PRIMED;
		}
		
		// this allows ball to be spawned in, but not timer count down
		inline void Reset()
		{
			mExplodeState = IDLE;
			mRespawnTime = 0;
		}
		
	};

	// keeps on exploding 
	class BumperExplodable : public ExplodableComponent
	{
		float mRegenerateTime;
		std::string mRespawnType;
	public:
		BumperExplodable( ExplosionType explosionType, float respawnTime, std::string respawnType) : 
		ExplodableComponent(explosionType), mRegenerateTime(respawnTime), mRespawnType(respawnType)
		{		
		}
		
		virtual bool DetonatesOtherCollider(){ return false;}
		
		virtual void OnCollision(Entity *collidesWith);
		virtual void FinalAnimation();
	};
	
	// pop, goes away  
	class PopExplodable : public ExplodableComponent
	{
		float mRegenerateTime;
		std::string mRespawnType;
	public:
		PopExplodable( ExplosionType explosionType, float respawnTime, std::string respawnType) : 
		ExplodableComponent(explosionType), mRegenerateTime(respawnTime), mRespawnType(respawnType)
		{		
		}
		
		virtual bool DetonatesOtherCollider(){ return false;}
		
		
		void OnCollision(Entity *collidesWith);
		virtual void FinalAnimation();
		
	};

}