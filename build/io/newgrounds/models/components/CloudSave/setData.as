
/**
 * setData
 * 
 * Component: CloudSave.setData
 * Saves data to a save slot. Any existing data will be replaced. Requires a session with a signed-in user attached; a session without one fails with a Login Required error.
 */
package io.newgrounds.models.components.CloudSave {
	
	import io.newgrounds.BaseComponent;
	
	public class setData extends BaseComponent {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The slot number.
		 */
		public var id:Number = 0;
		
		/**
		 * The data you want to save.
		 */
		public var data:String = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function setData() {
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
			return "CloudSave.setData";
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
			return ["id","data"];
		}
		
		/**
		 * Required properties for validation
		 */
		override public function get requiredProperties():Array {
			return ["id","data"];
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