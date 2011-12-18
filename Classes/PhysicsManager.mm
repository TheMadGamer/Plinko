/*
 *  PhysicsManager.cpp
 *  Gopher
 *
 *  Created by Anthony Lobay on 1/22/10.
 *  Copyright 2010 3dDogStudios. All rights reserved.
 *
 */
#import <btBulletDynamicsCommon.h>
#import <vector>
#import <algorithm>

#import "PhysicsComponent.h"
#import "PhysicsManager.h"
#import "Entity.h"
#import "GraphicsManager.h"

using namespace std;
	

namespace Dog3D
{
	typedef list<PhysicsComponent*>::iterator  PhysicsComponentIterator; 

	static inline void collideFlower(btCollisionObject* ob)
	{
		DLog(@"collide A");
		PhysicsComponent *pA = (PhysicsComponent*) ob->getUserPointer();
		
		Entity *entity = pA->GetParent();
		
		ExplodableComponent *explodable = entity->GetExplodable();
		
		if(explodable)
		{
			if(entity->GetExplodable()->IsPrimed())
			{
				PhysicsManager::Instance()->AddTriggeredObject(entity);
			}
			explodable->OnCollision(NULL);
			
		}
	}
	
	
	void mTickCallback( btDynamicsWorld *world, btScalar timeStep) {
		
		//if (world)
		//{
		//	world->performDiscreteCollisionDetection();
		//}
		
		///one way to draw all the contact points is iterating over contact manifolds / points:
		int numManifolds = world->getDispatcher()->getNumManifolds();
		
		
		for (int i=0;i<numManifolds;i++)
		{
			btPersistentManifold* contactManifold =  world->getDispatcher()->getManifoldByIndexInternal(i);
			btCollisionObject* obA = static_cast<btCollisionObject*>(contactManifold->getBody0());
			btCollisionObject* obB = static_cast<btCollisionObject*>(contactManifold->getBody1());
			
			short collisionGrpA = obA->getBroadphaseHandle()->m_collisionFilterGroup;
			short collisionGrpB = obB->getBroadphaseHandle()->m_collisionFilterGroup;
			
			if(  collisionGrpA & GRP_EXPLODABLE) 
			{
				collideFlower(obA);
			}
			
			if(collisionGrpB & GRP_EXPLODABLE )  
			{
				collideFlower(obB);
			}
		}
	}
	
	/*
	bool ContactAddedCallback( btManifoldPoint& cp,
								 const btCollisionObject* colObj0,
								 int partId0,
								 int index0,
								 const btCollisionObject* colObj1,
								 int partId1,
								 int index1)
	{
		DLog(@"GContact\n");
	}
	*/
	

	
	PhysicsManager * PhysicsManager::sPhysicsManager;
	
	void PhysicsManager::Initialize()
	{
		
/// DEBUG TODO		
		sPhysicsManager = new PhysicsManager();
	}
	
	void PhysicsManager::SetGravity(btVector3 &gravity)
	{
		mDynamicsWorld->setGravity(gravity);
	}
												
	
	void PhysicsManager::CreateWorld()
	{
		
		btVector3 worldAabbMin(-100,-4,-100);
		btVector3 worldAabbMax(100,4,100);
		int maxProxies = 256;
		mBroadphase = new btAxisSweep3(worldAabbMin,worldAabbMax,maxProxies);
		
		mCollisionConfiguration = new btDefaultCollisionConfiguration();
		mDispatcher = new btCollisionDispatcher(mCollisionConfiguration);
		
		mSolver = new btSequentialImpulseConstraintSolver;
		
		
		mDynamicsWorld = new btDiscreteDynamicsWorld(mDispatcher,mBroadphase,mSolver,mCollisionConfiguration);
		
		mDynamicsWorld->setGravity(btVector3(10,0,0));
		
		//TODO - goes in init?
		mDynamicsWorld->getBroadphase()->getOverlappingPairCache()->setInternalGhostPairCallback(new btGhostPairCallback());

		mDynamicsWorld->setInternalTickCallback(mTickCallback, this, false);
				
	}
	
	void PhysicsManager::AddComponent( PhysicsComponent *component  )
	{
		
		if(find( mManagedComponents.begin(), mManagedComponents.end(), component) == mManagedComponents.end())
		{
			btRigidBody *body = component->GetRigidBody();
			body->activate(true);
			
			((btDiscreteDynamicsWorld*) mDynamicsWorld)->addRigidBody( body, (short) component->GetCollisionGroup(), (short) component->GetCollidesWith() );	
			
			mManagedComponents.push_back(component);

		}
	}
	
	void PhysicsManager::RemoveComponent( PhysicsComponent *component)
	{
		PhysicsComponentIterator it = std::find(mManagedComponents.begin(), mManagedComponents.end(), component);
		if(it != mManagedComponents.end())
		{
#if DEBUG 
			DLog(@"Removing physics comp %s", ((*it)->GetParent()->mDebugName.c_str()));
#endif
			
			mManagedComponents.erase(it);
			mDynamicsWorld->removeRigidBody(component->GetRigidBody());
			
			btCollisionObject *collider = component->GetGhostCollider();
			if(collider)
			{
#if DEBUG 
				/*if((*it)->GetParent() != NULL)
				{
					DLog(@"Removing ghost collider %s", ((*it)->GetParent()->mDebugName.c_str()));
				}*/
#endif
				mDynamicsWorld->removeCollisionObject(collider);
			}
			
		}
		else 
		{
			DLog(@"Find to remove fail");
		}

	}	
	
	
	void PhysicsManager::Update(float deltaTime)
	{
		if(mDynamicsWorld == NULL)
		{
			return;
		}
		   
		
		// updates kinematic object position
		for(PhysicsComponentIterator it = mManagedComponents.begin(); it != mManagedComponents.end(); it++)
		{
			if((*it)->IsKinematic())
			{
				(*it)->Update(deltaTime);
			}
		}
		
		
		mDynamicsWorld->stepSimulation(deltaTime,10);
		
		// updates parent position
		for(PhysicsComponentIterator it = mManagedComponents.begin(); it != mManagedComponents.end(); it++)
		{
			if(!((*it)->IsKinematic()))
			{
				(*it)->Update(deltaTime);
			}
		}
		
		//for(PhysicsComponentIterator it = mManagedComponents.begin(); it != mManagedComponents.end(); it++)
		//{
		//	DLog(@"Debug ID %i %s", (*it)->GetRigidBody()->m_debugBodyId, (*it)->GetParent()->mDebugName.c_str());
		//}
		
	}
	
	
	// a flower
	void PhysicsManager::GetTriggerContactList(std::set<Entity *> &triggeredObjects)
	{
		triggeredObjects = mTriggeredObjects;
	
		mTriggeredObjects.clear();
	}
	
	
	
	void PhysicsManager::Unload()
	{
		for(PhysicsComponentIterator it = mManagedComponents.begin(); it!= mManagedComponents.end(); it++)
		{
			mDynamicsWorld->removeRigidBody((*it)->GetRigidBody());
			
		}
	
#if DEBUG
		if(mDynamicsWorld->getNumCollisionObjects())
		{
			DLog(@"WARNING: Num Objects still in world %i", mDynamicsWorld->getNumCollisionObjects());
		}
#endif
		
		mManagedComponents.clear();
	
		delete mDynamicsWorld;
		delete mSolver;
		delete mDispatcher;
		delete mCollisionConfiguration;
		
		delete mBroadphase;
		mTriggeredObjects.clear();
		
	
	
	}
#if 0
	void FakePhysicsManager::Update(float deltaTime)
	{
		DLog(@"Ican has update");
		
	}
	
	FakePhysicsManager::FakePhysicsManager(){}
	FakePhysicsManager::~FakePhysicsManager(){}
	
	void FakePhysicsManager::CreateWorld(){}
	bool FakePhysicsManager::RayIntersects(btVector3 &rayStart, btVector3 &rayEnd, Entity *ignoreThis){return false;}
	
	
	// initializes singleton manager
	void FakePhysicsManager::Unload(){}
	
	// adds a physics component (adds to world)
	// warning, does not add back ghost component
	void FakePhysicsManager::AddComponent( PhysicsComponent *component ){}
	
	// removes a physics component
	void FakePhysicsManager::RemoveComponent( PhysicsComponent *component){}
	
	
	// sets grav in physics world
	void FakePhysicsManager::SetGravity(btVector3 &gravity){}
	
	void FakePhysicsManager::GetTriggerContactList(std::set<EntityPair> &triggeredObjects){}
#endif	
}
