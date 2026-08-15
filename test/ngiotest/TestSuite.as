/**
 * TestSuite
 *
 * A named group of test cases. Subclasses override build() and call add()
 * once per test; the runner then walks the cases in registration order.
 *
 * Suites are also the unit of "needs the network": a suite that reports
 * isLive = true is skipped entirely when live testing is switched off.
 */
package ngiotest {

    public class TestSuite {

        //==================== PROPERTIES ====================

        /** Registered TestCase instances, in the order they were added */
        public var cases:Array = [];

        /** Set true by suites that talk to the gateway */
        public var isLive:Boolean = false;

        /**
         * The runner executing this suite. Assigned by TestRunner just before
         * build() is called, so a suite can influence the rest of the run -
         * see LiveGateSuite, which uses it to abandon the live suites.
         */
        public var runner:TestRunner;

        //==================== CONSTRUCTOR ====================

        public function TestSuite() {
            cases = [];
        }

        //==================== OVERRIDABLE ====================

        /**
         * Display name for this suite. Override in every subclass.
         */
        public function get suiteName():String {
            return "Unnamed Suite";
        }

        /**
         * Pause before each of this suite's cases, in milliseconds.
         *
         * Return -1 to use TestConfig.LIVE_TEST_PACING_MS like everything else.
         * Override when one suite needs to be gentler than the rest - see
         * LiveLoaderSuite, whose component appears to carry its own limit.
         *
         * Only consulted for live suites; offline suites are never paced.
         */
        public function get pacingMs():int {
            return -1;
        }

        /**
         * Register test cases here by calling add(). Called once, immediately
         * before the suite runs, so a suite can look at global state (such as
         * whether a user is logged in) while deciding what to register.
         */
        public function build():void {
            // Override in subclasses
        }

        /**
         * Runs once before the suite's first test. Call done() when ready.
         * The default implementation completes immediately.
         */
        public function setUp(done:Function):void {
            done.call(null);
        }

        /**
         * Runs once after the suite's last test. Call done() when finished.
         */
        public function tearDown(done:Function):void {
            done.call(null);
        }

        //==================== REGISTRATION ====================

        /**
         * Register a single test.
         *
         * @param name Human-readable description, shown in the report
         * @param fn   function(t:TestContext):void - must call t.done()
         */
        protected function add(name:String, fn:Function):void {
            cases.push(new TestCase(name, fn));
        }

        /**
         * Register a test that needs longer than the default watchdog, such as
         * one that waits on a person.
         *
         * @param name      Human-readable description
         * @param timeoutMs Watchdog for this test only
         * @param fn        function(t:TestContext):void - must call t.done()
         */
        protected function addSlow(name:String, timeoutMs:int, fn:Function):void {
            cases.push(new TestCase(name, fn, timeoutMs));
        }
    }
}
