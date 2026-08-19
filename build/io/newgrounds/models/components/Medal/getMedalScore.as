
/**
 * getMedalScore
 * 
 * Component: Medal.getMedalScore
 * Loads the user's current medal score. Requires a session with a signed-in user attached; a session without one fails with a Login Required error.
 */
package io.newgrounds.models.components.Medal {
	
	import io.newgrounds.BaseComponent;
	
	public class getMedalScore extends BaseComponent {
		
		//==================== PROPERTIES ====================
		
		
		//==================== CONSTRUCTOR ====================
		
		public function getMedalScore() {
			super();
			
			// Set component-specific flags
			this.isSecure = false;
			this.requiresSession = true;
			this.requiresLogin = true;
			this.redirect = false;
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Medal.getMedalScore";
		}
		
		/**
		 * Object type identifier
		 */
		override public function get objectType():String {
			return "component";
		}
		
		/**
		 * All property names for this component
		 */
		override public function get propertyNames():Array {
			return [];
		}
		
		/**
		 * Required properties for validation
		 */
		override public function get requiredProperties():Array {
			return [];
		}
		
		/**
		 * Type casting map for deserializing properties
		 */
		override public function get castTypes():Object {
			return {
			};
		}
		
		//==================== CUSTOM METHODS ====================
	}
}