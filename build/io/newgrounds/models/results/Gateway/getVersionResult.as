
/**
 * getVersionResult
 * 
 * Result for: Gateway.getVersion
 * Contains the data returned by the Gateway.getVersion API call
 */
package io.newgrounds.models.results.Gateway {
	
	import io.newgrounds.BaseResult;
	
	public class getVersionResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The version number (in X.Y.Z format).
		 */
public var version:String = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function getVersionResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Gateway.getVersion";
		}
		
		/**
		 * Object type identifier
		 */
		override public function get objectType():String {
			return "result";
		}
		
		/**
		 * All property names for this result
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