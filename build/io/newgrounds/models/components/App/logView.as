
/**
 * logView
 * 
 * Component: App.logView
 * Increments "Total Views" statistic.
 */
package io.newgrounds.models.components.App {
	
	import io.newgrounds.BaseComponent;
	
	public class logView extends BaseComponent {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The domain hosting your app. Examples: "www.somesite.com", "localHost"
		 */
		public var host:String = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function logView() {
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
			return "App.logView";
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