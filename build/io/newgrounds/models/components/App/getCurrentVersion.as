
/**
 * getCurrentVersion
 * 
 * Component: App.getCurrentVersion
 * Gets the version number of the app as defined in your "Version Control" settings.
 */
package io.newgrounds.models.components.App {
	
	import io.newgrounds.BaseComponent;
	
	public class getCurrentVersion extends BaseComponent {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The version number (in "X.Y.Z" format) of the client-side app. (default = "0.0.0")
		 */
		public var version:String = "0.0.0";
		
		
		//==================== CONSTRUCTOR ====================
		
		public function getCurrentVersion() {
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
			return "App.getCurrentVersion";
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
			return ["version"];
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