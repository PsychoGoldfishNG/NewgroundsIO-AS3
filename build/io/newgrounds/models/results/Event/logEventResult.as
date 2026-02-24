
/**
 * logEventResult
 * 
 * Result for: Event.logEvent
 * Contains the data returned by the Event.logEvent API call
 */
package io.newgrounds.models.results.Event {
	
	import io.newgrounds.BaseResult;
	
	public class logEventResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * 
		 */
public var event_name:String = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function logEventResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Event.logEvent";
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
			return ["event_name"];
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