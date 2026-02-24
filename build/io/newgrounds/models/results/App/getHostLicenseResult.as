
/**
 * getHostLicenseResult
 * 
 * Result for: App.getHostLicense
 * Contains the data returned by the App.getHostLicense API call
 */
package io.newgrounds.models.results.App {
	
	import io.newgrounds.BaseResult;
	
	public class getHostLicenseResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * 
		 */
public var host_approved:Boolean = false;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function getHostLicenseResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "App.getHostLicense";
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
			return ["host_approved"];
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