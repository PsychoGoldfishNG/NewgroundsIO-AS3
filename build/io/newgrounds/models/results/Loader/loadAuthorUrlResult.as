
/**
 * loadAuthorUrlResult
 * 
 * Result for: Loader.loadAuthorUrl
 * Contains the data returned by the Loader.loadAuthorUrl API call
 */
package io.newgrounds.models.results.Loader {
	
	import io.newgrounds.BaseResult;
	
	public class loadAuthorUrlResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The URL to redirect to. (This will only be returned if the redirect param is set to false.)
		 */
public var url:String = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function loadAuthorUrlResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Loader.loadAuthorUrl";
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
			return ["url"];
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