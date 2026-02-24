package tests {
    import io.newgrounds.models.objects.ScoreBoard;
    
    /**
     * Tests for ScoreBoard-specific functionality
     */
    public class ScoreBoardTest extends BaseTest {
        
        override public function runTests():Array {
            results = [];
            
            testScoreBoardCreation();
            testScoreBoardProperties();
            testScoreBoardSerialization();
            
            return results;
        }
        
        private function testScoreBoardCreation():void {
            var scoreBoard:ScoreBoard = new ScoreBoard();
            
            assertNotNull(scoreBoard, "ScoreBoard instance created");
            assertEquals("ScoreBoard", scoreBoard.objectName, "ScoreBoard object name correct");
            assertEquals("object", scoreBoard.objectType, "ScoreBoard object type correct");
        }
        
        private function testScoreBoardProperties():void {
            var scoreBoard:ScoreBoard = new ScoreBoard();
            scoreBoard.id = 42;
            scoreBoard.name = "High Scores";
            
            assertEquals(42, scoreBoard.id, "ScoreBoard ID set correctly");
            assertEquals("High Scores", scoreBoard.name, "ScoreBoard name set correctly");
        }
        
        private function testScoreBoardSerialization():void {
            var data:Object = {
                id: 99,
                name: "Test Board"
            };
            
            var scoreBoard:ScoreBoard = new ScoreBoard();
            scoreBoard.importFromObject(data);
            
            assertEquals(99, scoreBoard.id, "ScoreBoard ID deserialized");
            assertEquals("Test Board", scoreBoard.name, "ScoreBoard name deserialized");
        }
    }
}
