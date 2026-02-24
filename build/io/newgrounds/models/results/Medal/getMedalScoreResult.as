
/**
 * getMedalScoreResult
 * 
 * Result for: Medal.getMedalScore
 * Contains the data returned by the Medal.getMedalScore API call
 */
package io.newgrounds.models.results.Medal {
	
	import io.newgrounds.BaseResult;
	
	public class getMedalScoreResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The user's medal score.
		 */
public var medal_score:Number = NaN;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function getMedalScoreResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Medal.getMedalScore";
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
			return ["medal_score"];
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