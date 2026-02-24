
/**
 * logViewResult
 * 
 * Result for: App.logView
 * Contains the data returned by the App.logView API call
 */
package io.newgrounds.models.results.App {
	
	import io.newgrounds.BaseResult;
	
	public class logViewResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		
		//==================== CONSTRUCTOR ====================
		
		public function logViewResult() {
			super();
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
			return "result";
		}
		
		/**
		 * All property names for this result
		 */
		override public function get propertyNames():Array {
			return [];
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