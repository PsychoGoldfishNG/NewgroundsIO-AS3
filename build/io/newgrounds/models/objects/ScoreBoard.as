

/**
 * ScoreBoard
 * 
 * Contains information about a scoreboard.
 */
package io.newgrounds.models.objects {
	
	import io.newgrounds.BaseObject;
    import io.newgrounds.models.objects.Response;
    import io.newgrounds.models.results.ScoreBoard.getScoresResult;
    import io.newgrounds.models.results.ScoreBoard.postScoreResult;
    import io.newgrounds.models.objects.User;
	
	public class ScoreBoard extends BaseObject {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The numeric ID of the scoreboard.
		 */
		public var id:Number = NaN;
		
		/**
		 * The name of the scoreboard.
		 */
		public var name:String = null;
		
		
		//==================== CONSTRUCTOR ====================
		
		public function ScoreBoard() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "ScoreBoard";
		}
		
		/**
		 * Object type identifier
		 */
		override public function get objectType():String {
			return "object";
		}
		
		/**
		 * All property names for this object
		 */
		override public function get propertyNames():Array {
			return ["id","name"];
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
        /**
         * Loads scores from this scoreboard with optional filtering.
         * @param filters Object containing optional filters:
         *   - user_id (Number): Filter by user ID
         *   - user_name (String): Filter by username
         *   - user (io.newgrounds.models.objects.User): Filter by user object (uses id property)
         *   - period (String): 'D' (daily), 'W' (weekly), 'M' (monthly), 'Y' (yearly), 'A' (all-time, default 'D')
         *   - limit (Number): Results per page (1-100, default 10)
         *   - skip (Number): Pagination offset (default 0)
         *   - social (Boolean): Friends only (requires session)
         *   - tag (String): Filter by tag
         * @param callback Function to call with the loaded scores
         * @param thisArg Context to use when calling the callback
         */
        public function getScores(filters:Object = null, callback:Function = null, thisArg:* = null):void {
            if (!filters) {
                filters = {};
            }
            
            var componentParams:Object = {};
            
            // Set default period to daily
            if (filters.period === undefined || filters.period === null) {
                filters.period = 'D';
            }
            componentParams.period = filters.period;
            
            // Validate and set limit
            if (filters.limit === undefined || filters.limit === null) {
                filters.limit = 10;
            }
            
            if (filters.limit < 1) {
                throw new ArgumentError('ScoreBoard filter limit must be a number greater than 0.');
            }
            
            if (filters.limit > 100) {
                throw new ArgumentError('ScoreBoard filter limit must be a number less than or equal to 100.');
            }
            
            componentParams.limit = filters.limit;
            
            // Set skip for pagination
            if (filters.skip === undefined) {
                filters.skip = 0;
            }
            componentParams.skip = filters.skip;
            
            // Handle social filter (friends only)
            if (this.core && this.core.hasSession() && filters.social === true) {
                componentParams.social = true;
            }
            
            // Handle tag filter
            if (filters.tag !== undefined && filters.tag !== null) {
                componentParams.tag = filters.tag;
            }
            
            // Handle user filtering with strict typing
            // Check user_id (Number) first
            if (filters.user_id !== undefined && filters.user_id !== null) {
                if (typeof filters.user_id === 'number') {
                    componentParams.user = filters.user_id;
                } else {
                    throw new ArgumentError('ScoreBoard filter user_id must be a number.');
                }
            }
            // Check user_name (String) second
            else if (filters.user_name !== undefined && filters.user_name !== null) {
                if (typeof filters.user_name === 'string') {
                    componentParams.user = filters.user_name;
                } else {
                    throw new ArgumentError('ScoreBoard filter user_name must be a string.');
                }
            }
            // Check user (User object or object with id) third
            else if (filters.user !== undefined && filters.user !== null) {
                if (filters.user is io.newgrounds.models.objects.User) {
                    componentParams.user = filters.user.id;
                } else if (typeof filters.user === 'object' && filters.user.hasOwnProperty('id')) {
                    componentParams.user = filters.user.id;
                } else {
                    throw new ArgumentError('ScoreBoard filter user must be a User object with an id property.');
                }
            }
            
            // Add this scoreboard's ID
            componentParams.id = this.id;
            
            var callbackParams:Object = {
                callback: callback,
                thisArg: thisArg
            };
            
            if (this.core) this.core.callComponent("ScoreBoard.getScores", componentParams, this.onScoresLoaded, this, callbackParams);
        }
        
        /**
         * Callback handler for when scores are loaded.
         * @param response The Response object containing our results.
         * @param callbackParams The callback parameters stored during getScores()
         */
        internal function onScoresLoaded(response:io.newgrounds.models.objects.Response, callbackParams:Object):void {
            if (callbackParams.callback != null) {
                var result:io.newgrounds.models.results.ScoreBoard.getScoresResult = response.getResult() as io.newgrounds.models.results.ScoreBoard.getScoresResult;
                callbackParams.callback.call(callbackParams.thisArg, result.scores);
            }
        }
        
        /**
         * Posts a score to this scoreboard.
         * @param value The score value to post
         * @param tag Optional tag to associate with the score
         * @param callback Function to call when posting is complete
         * @param thisArg Context to use when calling the callback
         */
        public function postScore(value:Number, tag:String = null, callback:Function = null, thisArg:* = null):void {
            var componentParams:Object = {
                id: this.id,
                value: value
            };
            
            if (tag && tag.length > 0) {
                componentParams.tag = tag;
            }
            
            var callbackParams:Object = {
                callback: callback,
                thisArg: thisArg
            };
            
            if (this.core) this.core.callComponent("ScoreBoard.postScore", componentParams, this.onPostScore, this, callbackParams);
        }
        
        /**
         * Callback handler for when a score is posted.
         * @param response The response from ScoreBoard.postScore
         * @param callbackParams The callback parameters stored during postScore()
         */
        internal function onPostScore(response:Response, callbackParams:Object):void {
            if (callbackParams.callback != null) {
                var error:NgioError = null;
                var score:io.newgrounds.models.objects.Score = null;
                
                if (response && response.success) {
                    var result:io.newgrounds.models.results.ScoreBoard.postScoreResult = response.getResult() as io.newgrounds.models.results.ScoreBoard.postScoreResult;
                    if (result.success) {
                        score = result.score;
                    } else {
                        error = result.error;
                    }
                } else {
                    error = response.error;
                }
                
                callbackParams.callback.call(callbackParams.thisArg, score, error);
            }
        }
		
        /**
         * Returns a string representation of this scoreboard.
         */
        override public function toString():String {
            var description:String = "ScoreBoard #";
            description += (this.id != 0) ? this.id : "0";
            description += " - ";
            description += (this.name != null && this.name.length > 0) ? this.name : "null";
            return description;
        }
	}
}
