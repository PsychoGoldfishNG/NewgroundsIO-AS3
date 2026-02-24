package tests {
    /**
     * Interface for test suites
     */
    public interface ITestSuite {
        function runTests():Array; // Returns array of TestResult objects
    }
}
