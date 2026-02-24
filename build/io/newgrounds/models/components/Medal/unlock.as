
/**
 * unlock
 * 
 * Component: Medal.unlock
 * Unlocks a medal.
 */
package io.newgrounds.models.components.Medal {
	
	import io.newgrounds.BaseComponent;
	
	public class unlock extends BaseComponent {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The numeric ID of the medal to unlock.
		 */
		public var id:Number = NaN;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function unlock() {
			super();
			
			// Set component-specific flags
			this.isSecure = true;
			this.requiresSession = true;
			this.redirect = false;
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Medal.unlock";
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
			return ["id"];
		}
		
		/**
		 * Required properties for validation
		 */
		override public function get requiredProperties():Array {
			return ["id"];
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