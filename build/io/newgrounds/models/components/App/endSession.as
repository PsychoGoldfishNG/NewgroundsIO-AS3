
/**
 * endSession
 * 
 * Component: App.endSession
 * Ends the current session, if any.
 */
package io.newgrounds.models.components.App {
	
	import io.newgrounds.BaseComponent;
	
	public class endSession extends BaseComponent {
		
		//==================== PROPERTIES ====================
		
		
		//==================== CONSTRUCTOR ====================
		
		public function endSession() {
			super();
			
			// Set component-specific flags
			this.isSecure = false;
			this.requiresSession = true;
			this.redirect = false;
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "App.endSession";
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