package tests {
    /**
     * Base class for test suites with assertion helpers
     */
    public class BaseTest implements ITestSuite {
        
        protected var results:Array;
        
        public function BaseTest() {
            results = [];
        }
        
        public function runTests():Array {
            // Override in subclasses
            return results;
        }
        
        protected function assert(condition:Boolean, testName:String, message:String = ""):void {
            if (condition) {
                results.push(new TestResult(testName, true));
            } else {
                results.push(new TestResult(testName, false, message || "Assertion failed"));
            }
        }
        
        protected function assertEquals(expected:*, actual:*, testName:String):void {
            if (expected === actual) {
                results.push(new TestResult(testName, true));
            } else {
                results.push(new TestResult(testName, false, 
                    "Expected: " + expected + ", Actual: " + actual));
            }
        }
        
        protected function assertNotNull(value:*, testName:String):void {
            if (value !== null && value !== undefined) {
                results.push(new TestResult(testName, true));
            } else {
                results.push(new TestResult(testName, false, "Value was null or undefined"));
            }
        }
        
        protected function assertNull(value:*, testName:String):void {
            if (value === null || value === undefined) {
                results.push(new TestResult(testName, true));
            } else {
                results.push(new TestResult(testName, false, "Expected null, got: " + value));
            }
        }
        
        protected function assertTrue(value:Boolean, testName:String):void {
            assertEquals(true, value, testName);
        }
        
        protected function assertFalse(value:Boolean, testName:String):void {
            assertEquals(false, value, testName);
        }
    }
}
