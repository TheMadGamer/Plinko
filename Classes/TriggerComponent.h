/*
 *  TriggerComponent.h
 *
 *  Created by Anthony Lobay on 2/1/10.
 *  Copyright 2010 3dDogStudios. All rights reserved.
 *
 */

#import "Component.h"
#import "PhysicsManager.h"

namespace Dog3D
{

	
	// Collidable component
	class TriggerComponent : public Component
	{				
		
	public:
		enum TriggerType
		{
			REMOVE_GROUND, DO_SOMETHING_ELSE
		};
		
		TriggerComponent( TriggerType type, btVector3 &triggerPoint, float radius)
		{
			mTypeId = TRIGGER;
			mTriggerPoint = triggerPoint;
			mRadius = radius;
			mTriggerType = type;
			
			
		}
		
		virtual void Update(float deltaTime){}

		/*public void DeployPayload()
		{
			switch (mTriggerType) {
				case REMOVE_GROUND:
					
					
					break;
				default:
					break;
			}
		}*/
		
		bool CollidesWith(btVector3 &point)
		{
			float distance = (point.x() - mTriggerPoint.x()) *  (point.x() - mTriggerPoint.x()) + 
			(point.z() - mTriggerPoint.z()) * (point.z() - mTriggerPoint.z());
		
			return distance < mRadius;
		}
		
	protected:	
		btVector3 mTriggerPoint;		
		float mRadius;
		
		TriggerType mTriggerType;
		
		
	};
}