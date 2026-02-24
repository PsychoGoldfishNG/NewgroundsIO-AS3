
/**
 * unlockResult
 * 
 * Result for: Medal.unlock
 * Contains the data returned by the Medal.unlock API call
 */
package io.newgrounds.models.results.Medal {
	
	import io.newgrounds.BaseResult;
	import io.newgrounds.models.objects.Medal;
	
	public class unlockResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The #Medal that was unlocked.
		 */
public var medal:Medal = null;
		
		/**
		 * The user's new medal score.
		 */
public var medal_score:Number = NaN;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function unlockResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Medal.unlock";
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
			return ["medal","medal_score"];
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
				"medal": "Medal"
			};
		}
		
		//==================== CUSTOM METHODS ====================
	}
}