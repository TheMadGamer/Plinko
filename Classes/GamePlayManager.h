/*
 *  GamePlayManager.h
 *  Gopher
 *
 *  Created by Anthony Lobay on 2/1/10.
 *  Copyright 2010 3dDogStudios. All rights reserved.
 *
 */

#import <btBulletDynamicsCommon.h>
#import <vector>
#import <list>
#import "PhysicsComponent.h"
#import "TriggerComponent.h"

#import "NodeNetwork.h"
#import "SpawnComponent.h"
#import "Entity.h"
#import "VectorMath.h"
#import "GraphicsComponent.h"

#import "CannonController.h"
#import "CannonUI.h"
#import "ExplodableComponent.h"

namespace Dog3D
{
	typedef std::list< std::pair<float, int> >  IntervalQueue;
	typedef std::list< std::pair<float, int> >::iterator  IntervalQueueIterator;
	
	class GamePlayManager
	{
	public:
		enum GameState { PLAY, PAUSE, GOPHER_WIN, GOPHER_LOST };

	private:
		GameState mGameState;
		
	public:
		GamePlayManager(): 		mDestroyedObjects(0),
		mGameState(PLAY),
		mTouched(false), mFlicked(false),
		mCannonController(NULL), mCannonUI(NULL), 
		mUnlimitedBalls(true), mFocalPoint(0,0,0), 
		mSpawnDelay(0.0f)
		{}
	
		
		// singleton
		static GamePlayManager *Instance()
		{
			return sGamePlayManager;
		}
		
		static void ShutDown()
		{
			delete sGamePlayManager;
			sGamePlayManager = NULL;
		}
			
		
		void Unload();
		
		// initializes singleton manager
		static void Initialize();	
		
		// steps physics
		void Update(float deltaTime);

		
#pragma mark TOUCH
		//todo multi touch
		inline void Touch(btVector3 &position)
		{
#ifdef BUILD_PADDLE_MODE
			if(mPaddles.size() == 0 && mFlippers.size() ==  0 && 
			   mCannonController == NULL)
#else
			if(mCannonController == NULL)
#endif
			{
			
				if(mBalls.size() == 0)
				{
					DLog(@"No balls");
				}
				else {
									
					Dog3D::GraphicsComponent *gfx = mBalls.front()->GetGraphicsComponent();
					if(gfx->mActive)
					{
						mTouchPosition = position;
						mTouched = true;
					}
				}
			}
			else if(mCannonUI)
			{
				// update the cannon controller
				mCannonUI->SetTouch(position);
			}
#ifdef BUILD_PADDLE_MODE
			else if( mFlippers.size() > 0)
			{
				dynamic_cast<FlipperController*>(mFlippers[0] )->SetOn();
			}
			else
			{
				if(mPaddles.size() == 1)
				{					
					dynamic_cast<PaddleController*>(mPaddles[0] )->SetTarget(position);
				}
				else 
				{
					// positive then negative
					if(position.getZ() > 0)
					{
						dynamic_cast<PaddleController*>( mPaddles[0] )->SetTarget(position);
					}
					else {
						dynamic_cast<PaddleController*>( mPaddles[1] )->SetTarget(position);
					}

				}
			}
#endif
		}
		
		// write out old swipe, start a new one
		inline void StartSwipe(btVector3 &startPosition)
		{
			mCannonUI->StartSwipe(startPosition);
		}
		
		inline void MoveSwipe(btVector3 &endPosition)
		{
			
			// update the cannon controller
			mCannonUI->MoveSwipe(endPosition);	
		}
		
		inline void EndSwipe(btVector3 &endPosition)
		{
			// update the cannon controller
			mCannonUI->EndSwipe(endPosition);	
		}
		
		inline void CancelSwipe()
		{
			mCannonUI->CancelSwipe();
		}
		
		inline void SetFlick(btVector3 &flick)
		{
			mFlicked = true;
			mFlick = flick;
		}

#ifdef BUILD_PADDLE_MODE
		//todo multi touch
		inline void EndTouch()
		{
			if(mFlippers.size() > 0)
			{
				dynamic_cast<FlipperController*>(mFlippers[0])->SetOff();
			}
		}
#endif
		
		// returns position of ball 0
		inline btVector3 GetActiveBallPosition()
		{
			
			if(mBalls.size() > 0)
			{
				return mBalls.front()->GetPosition();
			}
			else {
				return btVector3(0,0,0);
			}
			
		}
		
#pragma mark SCENE SETUP
		// play, win
		inline GameState GetGameState() { return mGameState; }
		
		inline void SetGameState(GameState gameState){ mGameState = gameState;}
		
		
		inline void AddSpawnComponent(SpawnComponent *spawn)
		{
			mSpawnComponents.push_back(spawn);
		}
		
		inline void AddTarget(Entity *target)
		{
			mTargets.push_back(target);
		}
		
		inline void AddBall( Entity *ball, int ballType = 0)
		{
			if(ballType == ExplodableComponent::CUE_BALL)
			{
				mBalls.push_front(ball);
			}
			else 
			{
				mBalls.push_back(ball);
			}
		}
		
		
		inline void SetCannon( CannonController *controller, CannonUI *ui)
		{
			mCannonController = controller;
			mCannonUI = ui;
		}
		
		inline void SetGopherHUD( HUDGraphicsComponent *hud){ mGopherHUD = hud; }
		
		inline void SetCarrotHUD( HUDGraphicsComponent *hud){ mCarrotHUD = hud; }

		
		inline void SetWorldBounds(btVector3 &bounds)
		{
			mWorldBounds = bounds;
		}
		
		inline void GetFocalPoint(btVector3 &point)
		{
			
			point.setZero();
		}
			
		
#if DEBUG
		void DrawDebugLines();
#endif
		void RemoveTargetNode(int nodeId);
		
#pragma mark GAME LOGIC
		// reset of game win/loss logic
		// called during load up
		void InitializeLevel( int numGopherLives, int numCarrotLives)
		{
			
			
			//SetNumCarrotLives(numCarrotLives);
			mDestroyedObjects = 0;
			
			mLevelTime = 0;
		}
		
		// gophers or carrots = 0
		inline bool IsGameOver() { return  false; }
		
		
		inline void AddExplodable(ExplodableComponent *explodable)
		{
			mExplodables.push_back(explodable);
		}
		
		inline void SetUnlimitedBalls(bool enabled)
		{
			mUnlimitedBalls = enabled;
		}
		
#pragma mark SCORING
		
		
		//crude score test
		inline int ComputeScore()
		{
			return  0;
		}
		
		
		inline float GetLevelTime() { return mLevelTime;}
		
		
		
		inline void SetBallSpawn(btVector3 &bs)
		{
			mBallSpawn = bs;
		}
		
		
		inline int GetNumBallsLeft()
		{
			if(mCannonController != NULL)
			{
				return mCannonController->NumBallsLeft();
			}
			else {
				return -1;
			}
		}
        
        // spawns in single ball 
		void SpawnBall(Entity *ball, int position = 0);
		
	private:
		
		inline bool NoBallsLeft()
		{
			if( mCannonController == NULL)
			{
				return false;
			}
			
			if( mCannonController->NumBallsLeft() == 0 
			   && mBalls.size() == 0)
			{
				return true;
			}
			else
			{
				return false;
			}
		}
		  		
				
		void UpdateDebugVertices();

		
		// update object contact/explosion mojo		
		void UpdateObjectContacts(float dt);
		
		// steps ball and gopher controllers
		void UpdateControllers(float dt);
		
		// clean up exploded balls
		void UpdateBallExplosions(float dt);
		
		// manages spawn in
		bool ReclaimBalls(float dt);
		
		void ClampVelocity();
		
		// either continuous spawn or to cannon
		void ReclaimBall(Entity *ball);
		
		
		std::list<Entity *> mTargets;
		
		// managed components
		std::list<Entity *> mBalls;
		
		
		IntervalQueue mSpawnIntervals;
		
		HUDGraphicsComponent *mGopherHUD;
		HUDGraphicsComponent *mCarrotHUD;

		std::vector<SpawnComponent *> mSpawnComponents;
		
		std::list<ExplodableComponent *> mExplodables;
		
		
		// from UI
		btVector3 mTouchPosition;
		btVector3 mFlick;
		
		// for cannon control
		CannonController *mCannonController;
		CannonUI *mCannonUI;
		
		btVector3 mWorldBounds;
		
		btVector3 mFocalPoint;
		
		btVector3 mBallSpawn;
		
		// total play time on level
		float mLevelTime;
		

		float mSpawnDelay;
		
		// singleton
		static GamePlayManager *sGamePlayManager;
		
		int mNumDebugVertices;
		
#if DEBUG
		// debug
		Dog3D::Vec3 *mDebugVertices;
#endif
	
		// gas cans, etc
		int mDestroyedObjects;
		
		bool mUnlimitedBalls;
		
		// ui events passed in
		bool mTouched;
		bool mFlicked;
		
		// pool variant
		bool mScratched;
		
	};
}