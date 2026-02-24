

/**
 * Debug
 * 
 * Contains extra debugging information.
 */
package io.newgrounds.models.objects {
	
	import io.newgrounds.BaseObject;
	
	public class Debug extends BaseObject {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The time, in milliseconds, that it took to execute a request.
		 */
		public var exec_time:String = null;
		
		/**
		 * A copy of the request object that was posted to the server.
		 */
		public var request:io.newgrounds.models.objects.Request = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function Debug() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Debug";
		}
		
		/**
		 * Object type identifier
		 */
		override public function get objectType():String {
			return "object";
		}
		
		/**
		 * All property names for this object
		 */
		override public function get propertyNames():Array {
			return ["exec_time","request"];
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
				"request": "Request"
			};
		}
		
		//==================== CUSTOM METHODS ====================
	}
}
