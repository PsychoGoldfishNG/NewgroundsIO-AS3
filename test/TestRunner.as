package {
    import flash.display.Sprite;
    import flash.text.TextField;
    import flash.text.TextFormat;
    import tests.*;
    
    /**
     * Simple test runner for NewgroundsIO-AS3 library
     * Runs all test suites and displays results
     */
    public class TestRunner extends Sprite {
        
        private var output:TextField;
        private var passCount:int = 0;
        private var failCount:int = 0;
        
        public function TestRunner() {
            createOutputField();
            runTests();
        }
        
        private function createOutputField():void {
            output = new TextField();
            output.width = stage.stageWidth;
            output.height = stage.stageHeight;
            output.multiline = true;
            output.wordWrap = true;
            
            var format:TextFormat = new TextFormat();
            format.font = "Courier New";
            format.size = 12;
            output.defaultTextFormat = format;
            
            addChild(output);
        }
        
        private function runTests():void {
            log("==========================================");
            log("NewgroundsIO-AS3 Test Suite");
            log("==========================================\n");
            
            // Run test suites
            runTestSuite("BaseObject Tests", new BaseObjectTest());
            runTestSuite("Core Tests", new CoreTest());
            runTestSuite("Medal Tests", new MedalTest());
            runTestSuite("ScoreBoard Tests", new ScoreBoardTest());
            runTestSuite("SaveSlot Tests", new SaveSlotTest());
            runTestSuite("AppState Tests", new AppStateTest());
            runTestSuite("ObjectFactory Tests", new ObjectFactoryTest());
            
            // Display summary
            log("\n==========================================");
            log("Test Summary:");
            log("  Passed: " + passCount);
            log("  Failed: " + failCount);
            log("  Total:  " + (passCount + failCount));
            log("==========================================");
            
            if (failCount == 0) {
                log("\n✓ ALL TESTS PASSED!");
            } else {
                log("\n✗ SOME TESTS FAILED!");
            }
        }
        
        private function runTestSuite(name:String, suite:ITestSuite):void {
            log("\n" + name + ":");
            log("------------------------------------------");
            
            var results:Array = suite.runTests();
            for each (var result:TestResult in results) {
                if (result.passed) {
                    log("  ✓ " + result.name);
                    passCount++;
                } else {
                    log("  ✗ " + result.name);
                    log("    " + result.message);
                    failCount++;
                }
            }
        }
        
        private function log(message:String):void {
            output.appendText(message + "\n");
        }
    }
}
