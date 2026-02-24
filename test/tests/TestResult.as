package tests {
    /**
     * Represents the result of a single test
     */
    public class TestResult {
        public var name:String;
        public var passed:Boolean;
        public var message:String;
        
        public function TestResult(name:String, passed:Boolean, message:String = "") {
            this.name = name;
            this.passed = passed;
            this.message = message;
        }
    }
}
