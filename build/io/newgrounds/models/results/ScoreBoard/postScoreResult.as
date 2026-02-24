
/**
 * postScoreResult
 * 
 * Result for: ScoreBoard.postScore
 * Contains the data returned by the ScoreBoard.postScore API call
 */
package io.newgrounds.models.results.ScoreBoard {
	
	import io.newgrounds.BaseResult;
	import io.newgrounds.models.objects.ScoreBoard;
	import io.newgrounds.models.objects.Score;
	
	public class postScoreResult extends BaseResult {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The #ScoreBoard that was posted to.
		 */
public var scoreboard:ScoreBoard = null;
		
		/**
		 * The #Score that was posted to the board.
		 */
public var score:Score = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function postScoreResult() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "ScoreBoard.postScore";
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
			return ["scoreboard","score"];
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
				"scoreboard": "ScoreBoard",
				"score": "Score"
			};
		}
		
		//==================== CUSTOM METHODS ====================
	}
}