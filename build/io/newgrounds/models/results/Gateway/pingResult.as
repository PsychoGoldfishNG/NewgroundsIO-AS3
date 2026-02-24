
/**
 * pingResult
 * 
 * Result for: Gateway.ping
 * Contains the data returned by the Gateway.ping API call
 */
package io.newgrounds.models.results.Gateway {
	
	import io.newgrounds.BaseResult;
	
	public class pingResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * Will always return a value of 'pong'
		 */
public var pong:String = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function pingResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Gateway.ping";
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
			return ["pong"];
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