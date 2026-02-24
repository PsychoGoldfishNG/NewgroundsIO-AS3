
/**
 * postScore
 * 
 * Component: ScoreBoard.postScore
 * Posts a score to the specified scoreboard.
 */
package io.newgrounds.models.components.ScoreBoard {
	
	import io.newgrounds.BaseComponent;
	
	public class postScore extends BaseComponent {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The numeric ID of the scoreboard.
		 */
		public var id:Number = NaN;
		
		/**
		 * The int value of the score.
		 */
		public var value:Number = NaN;
		
		/**
		 * An optional tag that can be used to filter scores via ScoreBoard.getScores
		 */
		public var tag:String = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function postScore() {
			super();
			
			// Set component-specific flags
			this.isSecure = true;
			this.requiresSession = true;
			this.redirect = false;
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
			return "component";
		}
		
		/**
		 * All property names for this component
		 */
		override public function get propertyNames():Array {
			return ["id","value","tag"];
		}
		
		/**
		 * Required properties for validation
		 */
		override public function get requiredProperties():Array {
			return ["id","value"];
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