

/**
 * NgioError
 * 
 * 
 */
package io.newgrounds.models.objects {
	
	import io.newgrounds.BaseObject;
	
	public class NgioError extends BaseObject {
		
		//==================== PROPERTIES ====================
		
		/**
		 * Contains details about the error.
		 */
		public var message:String = null;
		
		/**
		 * A code indicating the error type.
		 */
		public var code:Number = NaN;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function NgioError() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Error";
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
			return ["message","code"];
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
		/**
		 * Returns the error message if set, otherwise "null".
		 */
		override public function toString():String {
			return (this.message != null && this.message.length > 0) ? this.message : "null";
		}
	}
}
