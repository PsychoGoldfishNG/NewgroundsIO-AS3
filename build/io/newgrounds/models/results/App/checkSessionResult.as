
/**
 * checkSessionResult
 * 
 * Result for: App.checkSession
 * Contains the data returned by the App.checkSession API call
 */
package io.newgrounds.models.results.App {
	
	import io.newgrounds.BaseResult;
	import io.newgrounds.models.objects.Session;
	
	public class checkSessionResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * 
		 */
public var session:Session = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function checkSessionResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "App.checkSession";
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
			return ["session"];
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
				"session": "Session"
			};
		}
		
		//==================== CUSTOM METHODS ====================
	}
}