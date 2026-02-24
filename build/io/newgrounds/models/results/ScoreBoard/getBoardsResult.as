
/**
 * getBoardsResult
 * 
 * Result for: ScoreBoard.getBoards
 * Contains the data returned by the ScoreBoard.getBoards API call
 */
package io.newgrounds.models.results.ScoreBoard {
	
	import io.newgrounds.BaseResult;
	
	public class getBoardsResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * An array of #ScoreBoard objects.
		 */
public var scoreboards:Array = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function getBoardsResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "ScoreBoard.getBoards";
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
			return ["scoreboards"];
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
				"scoreboards": "array-of-ScoreBoard"
			};
		}
		
		//==================== CUSTOM METHODS ====================
	}
}