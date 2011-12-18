//
//  GopherView.m
//  Gopher
//
//  Copyright 2010 3dDogStudios. All rights reserved.
//


#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/ES1/gl.h>

#import <vector>

#import <btBulletDynamicsCommon.h>

#import "GopherView.h"

#import "GameEntityFactory.h"

#import "PhysicsManager.h"
#import "GraphicsManager.h"
#import "GamePlayManager.h"
#import "SceneManager.h"
#import "AudioDispatch.h"

#import "FakeGLU.h"

#import "TriggerComponent.h"

using namespace Dog3D;
using namespace std;

const float kBallRadius = 0.5;

float kWallHeight = 1;

@implementation GopherView

@synthesize gopherViewController;

@synthesize offsetGravityEnabled;

@synthesize tiltGravityCoef;

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		
		srand(time(0));
		
		boundWidth = 20.0;
		boundHeight = 30.0; 
		boundDepth = 4.0;
		
		fpsTime = 0;
		fpsFrames = 0;
		
		physFrames = 0;
		physTime = 0;
		
		zEye = 40;
		delayFrames = 0;
		
		mViewState = LOAD;
		
		mScore = -1;
		mNumBallsLeft = -1;
		
		touchStartTime = 0;
		touchStart.setZero();
		
		touchMode = CANNON;
		touchStarted = false;
		graphics3D = false;

		lastTimeInterval = [NSDate timeIntervalSinceReferenceDate];

		
		mEngineInitialized = false;
		
		offsetGravityEnabled = true;
		tiltGravityCoef = 20.0f;
		
		fX = 0;
		fY = 0;
			
		
	}
	
	return self;
}

- (void) setGraphics3D:(bool) set3D
{
	graphics3D = set3D;
	GraphicsManager::Instance()->SetGraphics3D(set3D);
}


- (void) pauseGame
{
	mViewState = PAUSE;
}

- (void) resumeGame
{
	mViewState = PLAY;
}

- (void) initEngine
{
	if(mEngineInitialized)
	{
		return;
	}
	
	PhysicsManager::Initialize();
	GraphicsManager::Initialize();
	GamePlayManager::Initialize();
	SceneManager::Initialize();
	AudioDispatch::Initialize();
	
	mEngineInitialized = true;
}

-(bool) isEngineInitialized
{
	return mEngineInitialized;
}

- (void) reloadLevel
{
	NSString *level = [[NSString alloc] initWithUTF8String:SceneManager::Instance()->GetSceneName().c_str()];
	
	SceneManager::Instance()->UnloadScene();
	[self loadLevel:level];
	
}

- (NSString*) loadedLevel
{
	return mLoadedLevel;
}

- (int) currentScore
{
	return GamePlayManager::Instance()->ComputeScore();
}


- (void) loadLevel:(NSString*) levelName
{

	DLog(@"GView Load Level");
	if([levelName isEqualToString:@"Splash"])
	{
		mViewState = LOAD;
		return;
	}
	
	[levelName retain];
	
	if(mLoadedLevel != nil)
	{
		[mLoadedLevel release];
	}
	
	mLoadedLevel = levelName;
	
	SceneManager::Instance()->LoadScene(levelName);
	GamePlayManager::Instance()->SetGameState(GamePlayManager::PLAY);
	

	touchMode = CANNON;
	self.animationInterval = 1.0 / 60.0;
	
	
	int score = GamePlayManager::Instance()->ComputeScore();

	int ballsLeft = GamePlayManager::Instance()->GetNumBallsLeft();
	
			
	// update score if it has changed
	[ gopherViewController updateScore: score withDead:0 andTotal: 10];
	
	mViewState = PLAY;
	DLog(@"GView Done Load");
}

- (void)drawView 
{	
	if(mViewState == PAUSE)
	{
		return; 
	}
	
	[EAGLContext setCurrentContext:context];
	
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
		
	
	if(!mEngineInitialized)
	{
		[self initEngine];
	}
	
	if(mViewState == LOAD ) 
	{
		// final draw
		GraphicsManager::Instance()->OrthoViewSetup(backingWidth, backingHeight, zEye);		
		
		
		GraphicsManager::Instance()->OrthoViewCleanUp();
		
		mViewState = PAUSE;

		// record these
		startTimeInterval = [NSDate timeIntervalSinceReferenceDate];
		lastTimeInterval = [NSDate timeIntervalSinceReferenceDate];
		
		[gopherViewController finishedLoadUp];
		
	}
	
	
	if(mViewState == PLAY)	
	{
		// transition out of Play
		if(GamePlayManager::Instance()->GetGameState() == GamePlayManager::GOPHER_WIN ||
		   GamePlayManager::Instance()->GetGameState() == GamePlayManager::GOPHER_LOST)
		{
			mViewState = (GamePlayManager::Instance()->GetGameState() == GamePlayManager::GOPHER_LOST)? GOPHER_LOST : GOPHER_WIN;
			
			// message delegate
			[gopherViewController finishedLevel:(mViewState == GOPHER_LOST)]; 
		}
		
	}
	
		
	if(mViewState == PLAY || mViewState == GOPHER_WIN || mViewState == GOPHER_LOST)
	{
		// strangely, there must be no GL context or something in the init 
		GraphicsManager::Instance()->SetupLights();
		GraphicsManager::Instance()->SetupView(
											   backingWidth,  
											   backingHeight,  
											   zEye
											   );
		
		
		glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		double dt = ([NSDate timeIntervalSinceReferenceDate] - lastTimeInterval);
		
		
		lastTimeInterval = [NSDate timeIntervalSinceReferenceDate];	
#if DEBUG
		if(fpsTime > 1.0f)
		{
			float fps = fpsFrames / fpsTime;
			
			NSLog(@"FPS : %f", fps);
				
			fpsTime = 0;
			fpsFrames = 0;
		}
		else {
			fpsFrames++;
			fpsTime += dt;
		}
#endif
		// clamp dt
		dt = MIN(0.2, dt);
		
		PhysicsManager::Instance()->Update(dt);
		GamePlayManager::Instance()->Update(dt);	
		GraphicsManager::Instance()->Update(dt);

		if(mViewState == PLAY)
		{
			SceneManager::Instance()->Update(dt);
		}
		
		int score = GamePlayManager::Instance()->ComputeScore();

		int ballsLeft = GamePlayManager::Instance()->GetNumBallsLeft();
		
		
		{
			if(score != mScore )
			{
				// update score if it has changed
				[ gopherViewController updateScore: score withDead:0 andTotal: 10];
			}
		}
		mScore = score;

		mNumBallsLeft = ballsLeft;
	}

	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
	
	
	int error = glGetError();
	if(error )
	{ 
		DLog(@"Gl error. Still effed up %d?", error);
	}

}

-(void) endLevel
{
	SceneManager::Instance()->UnloadScene();
	if(mLoadedLevel != nil)
	{
		[mLoadedLevel release];
		mLoadedLevel = nil;
	}
}

- (btVector3) getTouchPoint:( CGPoint ) touchPoint
{
	// map touch into local coordinates
	float x = touchPoint.x/320.0;
	float y = touchPoint.y/480.0;
	
	x -= 0.5;
	x *= -20.0;
	
	y -= 0.5;
	y *= -30.0;
	
	return btVector3(x, 0, y);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{	
	CGPoint touchPoint = [[touches anyObject] locationInView:self];
	
	if(mViewState != PLAY)
	{
		return;
	}
	
	// check for pause touch
	{
		btVector3 touchPt = [self getTouchPoint:touchPoint];
		touchPt -= btVector3(-9,0,-14);
		
		if(touchPt.length() < 1.5f)
		{
			[gopherViewController pauseLevel];
		}
		
	}
	
	
	
	if( touchMode == SINGLE_TOUCH)
	{
		return;
	}
	   
	{

		for (UITouch *touch in touches) 
		{
			//UITouch *touch = [touches anyObject];
			
			CGPoint touchPoint = [touch locationInView:self];
			touchStart = [self getTouchPoint:touchPoint];
			
			//changed this to allow run cannon
			if(touchStart.z() > -10)
			{
				GamePlayManager::Instance()->StartSwipe(touchStart);
				//mDidMove = false;
			}
			else {
				GamePlayManager::Instance()->Touch(touchStart);			
			}
		}
	}	
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{

	if(mViewState != PLAY)
	{
		return;
	}
	
	if(touchMode == CANNON )
	{
		
		for (UITouch *touch in touches) 
		{

			// TODO : send in a relative motion	
			//UITouch *touch = [touches anyObject];
			
			CGPoint touchPoint = [touch locationInView:self];
			
			btVector3 touchPosition = [self getTouchPoint:touchPoint];
			if(touchPosition.z() > 0)
			{
				GamePlayManager::Instance()->MoveSwipe(touchPosition);
				mDidMove = true;
			}
		}
	}
	else if(touchMode != FLICK && touchMode != TILT_ONLY && touchMode != SINGLE_TOUCH)
	{
		// multi touch mode		
		for (UITouch *touch in touches) {
			
			CGPoint point = [touch locationInView:self];
			
			CGPoint touchPoint = [touch locationInView:self];
			
			btVector3 touchPosition = [self getTouchPoint:touchPoint];
			
			GamePlayManager::Instance()->Touch(touchPosition);
		}
	} 
	
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	touchStarted = false;
	
	//GamePlayManager::Instance()->CancelSwipe();
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{

	UITouch *touch = [touches anyObject];
	
	if(mViewState == LOAD || mViewState == GOPHER_WIN || mViewState == GOPHER_LOST
	 || touchMode == TILT_ONLY )  
	{
		return;
	}
	
	if (touchMode == CANNON ) {
		
		return; /////////////////////////////////// RETURN ///////////////
		
	}
#ifdef FLICK_MODE_ENABLED
	else if(touchMode == FLICK)
	{
		if(touchStarted)
		{
			
			CFTimeInterval thisFrameStartTime = CFAbsoluteTimeGetCurrent();    
			double dt = thisFrameStartTime - touchStartTime;
			
			if(dt < 2.0)
			{
			
				CGPoint touchPoint = [touch locationInView:self];
				
				btVector3 touchEnd = [self getTouchPoint:touchPoint];
				
				
				DLog(@"Flick: Start %0.1f %0.1f, End: %0.1f %0.1f, Dt %0.2f ",
					  touchStart.x(), touchStart.z(), touchEnd.x(), touchEnd.z(), dt);
				
				touchEnd -= touchStart;
				
				touchEnd /= dt;
				
				GamePlayManager::Instance()->SetFlick(touchEnd);
				
			}
			touchStarted = false;
		}
	}
#endif
	else
	{
			
		//for (UITouch *touch in touches) {

			CGPoint point = [touch locationInView:self];
			
			CGPoint touchPoint = [touch locationInView:self];
			
			btVector3 touchPosition = [self getTouchPoint:touchPoint];
			
			GamePlayManager::Instance()->Touch(touchPosition);
		//}
	}
}

inline float clamp(float a, float mn, float mx)
{
	if(a > mx)
	{
		return mx;
	}
	if(a < mn)
	{
		return mn;
	}
	return a;
	
}

-(void) dealloc
{	
	GamePlayManager::ShutDown();
	GraphicsManager::ShutDown();
	PhysicsManager::ShutDown();
	SceneManager::ShutDown();
	AudioDispatch::ShutDown();
	
	[super dealloc];	
}
 
@end

