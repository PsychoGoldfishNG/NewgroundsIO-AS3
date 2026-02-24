
/**
 * loadOfficialUrl
 * 
 * Component: Loader.loadOfficialUrl
 * Loads the official URL where the latest version of your app can be found (as defined in your "Official URLs" settings), and logs a referral to your API stats.
 */
package io.newgrounds.models.components.Loader {
	
	import io.newgrounds.BaseComponent;
	
	public class loadOfficialUrl extends BaseComponent {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The domain hosting your app. Example: "www.somesite.com", "localHost"
		 */
		public var host:String = null;
		
		/**
		 * Set this to false to skip logging this as a referral event.
		 */
		public var log_stat:Boolean = true;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function loadOfficialUrl() {
			super();
			
			// Set component-specific flags
			this.isSecure = false;
			this.requiresSession = false;
			this.redirect = true;
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Loader.loadOfficialUrl";
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
			return ["host","redirect","log_stat"];
		}
		
		/**
		 * Required properties for validation
		 */
		override public function get requiredProperties():Array {
			return ["host"];
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