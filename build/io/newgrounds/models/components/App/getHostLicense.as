
/**
 * getHostLicense
 * 
 * Component: App.getHostLicense
 * Checks a client-side host domain against domains defined in your "Game Protection" settings.
 */
package io.newgrounds.models.components.App {
	
	import io.newgrounds.BaseComponent;
	
	public class getHostLicense extends BaseComponent {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The host domain to check (ei, somesite.com).
		 */
		public var host:String = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function getHostLicense() {
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
			return "App.getHostLicense";
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
			return ["host"];
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