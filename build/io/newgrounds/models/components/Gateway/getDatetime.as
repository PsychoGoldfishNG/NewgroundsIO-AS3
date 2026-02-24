
/**
 * getDatetime
 * 
 * Component: Gateway.getDatetime
 * Loads the current date and time from the Newgrounds.io server.
 */
package io.newgrounds.models.components.Gateway {
	
	import io.newgrounds.BaseComponent;
	
	public class getDatetime extends BaseComponent {
		
		//==================== PROPERTIES ====================
		
		
		//==================== CONSTRUCTOR ====================
		
		public function getDatetime() {
			super();
			
			// Set component-specific flags
			this.isSecure = false;
			this.requiresSession = false;
			this.redirect = false;
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Gateway.getDatetime";
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