
/**
 * setDataResult
 * 
 * Result for: CloudSave.setData
 * Contains the data returned by the CloudSave.setData API call
 */
package io.newgrounds.models.results.CloudSave {
	
	import io.newgrounds.BaseResult;
	import io.newgrounds.models.objects.SaveSlot;
	
	public class setDataResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * 
		 */
public var slot:SaveSlot = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function setDataResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "CloudSave.setData";
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
			return ["slot"];
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
				"slot": "SaveSlot"
			};
		}
		
		//==================== CUSTOM METHODS ====================
	}
}