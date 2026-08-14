/**
 * TestCase
 *
 * A single named test. `fn` receives a TestContext and must call done() on it,
 * either synchronously or from a callback.
 */
package ngiotest {

    public class TestCase {

        /** Description shown in the report */
        public var name:String;

        /** function(t:TestContext):void */
        public var fn:Function;

        /**
         * Per-test override for the runner's timeout, in milliseconds.
         * Left at 0 to use the suite-wide default from TestConfig.
         */
        public var timeoutMs:int = 0;

        public function TestCase(name:String, fn:Function, timeoutMs:int = 0) {
            this.name = name;
            this.fn = fn;
            this.timeoutMs = timeoutMs;
        }
    }
}
