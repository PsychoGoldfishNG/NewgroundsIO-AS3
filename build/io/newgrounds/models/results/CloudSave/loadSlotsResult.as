
/**
 * loadSlotsResult
 * 
 * Result for: CloudSave.loadSlots
 * Contains the data returned by the CloudSave.loadSlots API call
 */
package io.newgrounds.models.results.CloudSave {
	
	import io.newgrounds.BaseResult;
	
	public class loadSlotsResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * An array of #SaveSlot objects.
		 */
public var slots:Array = null;
		
		/**
		 * The App ID the loaded slots belong to, if loaded from an external app.
		 */
public var app_id:String = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function loadSlotsResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "CloudSave.loadSlots";
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
			return ["slots","app_id"];
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
				"slots": "array-of-SaveSlot"
			};
		}
		
		//==================== CUSTOM METHODS ====================
	}
}