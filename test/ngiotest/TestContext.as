/**
 * TestContext
 *
 * Handed to every test function. Carries the assertions, the "I'm finished"
 * signal, and access to the on-stage prompt for tests that need a human.
 *
 * Tests are async by default: the runner does not move on until done() is
 * called. Purely synchronous tests simply call done() as their last statement.
 */
package ngiotest {

    import io.newgrounds.BaseObject;
    import io.newgrounds.NGJSON;

    public class TestContext {

        //==================== PROPERTIES ====================

        /** Name of the test being run, used in the report */
        public var name:String;

        /** Failure messages collected by the assert* methods */
        public var failures:Array;

        /** Informational lines a test chose to record (always shown) */
        public var notes:Array;

        /** Number of assertions that passed, for a per-test count */
        public var assertionCount:int = 0;

        /** Set when the test asked to be skipped rather than pass/fail */
        public var skipped:Boolean = false;

        /** Reason recorded alongside a skip */
        public var skipReason:String = null;

        /** Shared prompt/status UI */
        public var ui:TestUI;

        /**
         * Set when this test put a prompt on screen and waited for a person.
         *
         * The runner subtracts such cases from the headline duration, because
         * the interesting number is what the SUITE costs. A run left sitting on
         * the live-testing gate reported its whole thinking time as suite time,
         * which reads as a slow run rather than a distracted tester - and that
         * figure is what gets used to judge whether the pacing is too high.
         */
        public var waitedForInput:Boolean = false;

        /**
         * Optional hook invoked instead of the default "timed out" failure when
         * the runner's watchdog fires. Set it when a timeout is a legitimate
         * outcome rather than a fault - a prompt nobody answered, say. The hook
         * is expected to finish the test; if it does not, the normal failure
         * still applies.
         */
        public var onTimeout:Function = null;

        /** Invoked exactly once, when the test signals completion */
        private var onDone:Function;

        /** Guards against a test calling done() twice (common with callbacks) */
        private var finished:Boolean = false;

        //==================== CONSTRUCTOR ====================

        public function TestContext(name:String, ui:TestUI, onDone:Function) {
            this.name = name;
            this.ui = ui;
            this.onDone = onDone;
            this.failures = [];
            this.notes = [];
        }

        //==================== COMPLETION ====================

        /**
         * Signal that this test is finished. Safe to call more than once -
         * later calls are ignored, which matters because a flaky async path
         * can otherwise advance the runner twice and corrupt the report.
         */
        public function done():void {
            if (finished) {
                return;
            }
            finished = true;
            onDone.call(null, this);
        }

        /** True once done() has been honoured */
        public function get isFinished():Boolean {
            return finished;
        }

        /**
         * Abandon this test without counting it as a failure, e.g. when a
         * precondition the test cannot control (no login) isn't met.
         */
        public function skip(reason:String):void {
            skipped = true;
            skipReason = reason;
            done();
        }

        //==================== ASSERTIONS ====================

        /**
         * Record an unconditional failure.
         */
        public function fail(message:String):void {
            failures.push(message);
        }

        /**
         * Record a note that shows up in the report regardless of pass/fail.
         * Use it for server-supplied values worth eyeballing (user names,
         * gateway versions, medal counts).
         */
        public function note(message:String):void {
            notes.push(message);
        }

        public function assert(condition:Boolean, message:String):Boolean {
            if (condition) {
                assertionCount++;
                return true;
            }
            failures.push(message);
            return false;
        }

        /**
         * Compares with == rather than ===, because values arriving from JSON
         * are frequently a different numeric type than the literal written in
         * the test (int vs Number) while being the same value.
         */
        public function assertEquals(expected:*, actual:*, message:String):Boolean {
            if (expected == actual) {
                assertionCount++;
                return true;
            }
            failures.push(message + " -- expected <" + describe(expected) + ">, got <" + describe(actual) + ">");
            return false;
        }

        public function assertStrictEquals(expected:*, actual:*, message:String):Boolean {
            if (expected === actual) {
                assertionCount++;
                return true;
            }
            failures.push(message + " -- expected strictly <" + describe(expected) + ">, got <" + describe(actual) + ">");
            return false;
        }

        public function assertNotEquals(unexpected:*, actual:*, message:String):Boolean {
            if (unexpected != actual) {
                assertionCount++;
                return true;
            }
            failures.push(message + " -- expected anything but <" + describe(unexpected) + ">");
            return false;
        }

        public function assertNotNull(value:*, message:String):Boolean {
            if (value !== null && value !== undefined) {
                assertionCount++;
                return true;
            }
            failures.push(message + " -- value was null/undefined");
            return false;
        }

        public function assertNull(value:*, message:String):Boolean {
            if (value === null || value === undefined) {
                assertionCount++;
                return true;
            }
            failures.push(message + " -- expected null, got <" + describe(value) + ">");
            return false;
        }

        public function assertTrue(value:*, message:String):Boolean {
            return assertStrictEquals(true, value, message);
        }

        public function assertFalse(value:*, message:String):Boolean {
            return assertStrictEquals(false, value, message);
        }

        public function assertIsType(value:*, type:Class, message:String):Boolean {
            if (value is type) {
                assertionCount++;
                return true;
            }
            failures.push(message + " -- got <" + describe(value) + ">");
            return false;
        }

        /**
         * Assert a value sits within a tolerance of a target. Used for clock
         * comparisons against the server, which will never match exactly.
         */
        public function assertWithin(expected:Number, actual:Number, tolerance:Number, message:String):Boolean {
            var difference:Number = Math.abs(expected - actual);
            if (difference <= tolerance) {
                assertionCount++;
                return true;
            }
            failures.push(message + " -- " + actual + " is " + difference + " away from " + expected + " (tolerance " + tolerance + ")");
            return false;
        }

        /**
         * Assert that calling fn throws. Returns the caught error, or null.
         */
        public function assertThrows(fn:Function, message:String):Error {
            try {
                fn.call(null);
            } catch (e:Error) {
                assertionCount++;
                return e;
            }
            failures.push(message + " -- no error was thrown");
            return null;
        }

        /**
         * Asserts that fn runs to completion.
         *
         * The mirror of assertThrows, for guards that must NOT fire: one that
         * blocks too much is as real a bug as one that blocks too little, and
         * "it didn't throw" is otherwise an assertion no test actually records.
         */
        public function assertDoesNotThrow(fn:Function, message:String):void {
            try {
                fn.call(null);
                assertionCount++;
            } catch (e:Error) {
                failures.push(message + " -- threw " + e.message);
            }
        }

        //==================== HUMAN INPUT ====================

        /**
         * Show a message plus a button and wait for the user to click it.
         * The button is hidden again before the handler runs.
         */
        public function prompt(message:String, buttonLabel:String, handler:Function):void {
            if (ui == null || !ui.hasButton) {
                fail("Test needs the on-stage button but the .fla did not supply one");
                done();
                return;
            }
            waitedForInput = true;
            ui.setInfo(message);
            ui.showButton(buttonLabel, handler);
        }

        /**
         * Offer the user a genuine either/or choice, using both on-stage buttons.
         *
         * SKIPS rather than fails when the .fla has only one button, because
         * unlike prompt() there is no sensible default: the whole point is that
         * the test cannot know which branch the user wants. A one-button .fla is
         * an older stage layout, not a broken one.
         *
         * Exactly one handler runs - showButtons() tears both down on the first
         * click.
         */
        public function promptChoice(message:String, buttonLabel:String, handler:Function,
                                     buttonLabel2:String, handler2:Function):void {
            if (ui == null || !ui.hasButton) {
                fail("Test needs the on-stage button but the .fla did not supply one");
                done();
                return;
            }

            if (!ui.hasButton2) {
                skip("needs the second on-stage button (inputButton2) and this .fla has only one");
                return;
            }

            waitedForInput = true;
            ui.setInfo(message);
            ui.showButtons(buttonLabel, handler, buttonLabel2, handler2);
        }

        /**
         * Replace the on-stage text for the rest of THIS case.
         *
         * Reserved for telling a person what is being waited on after they have
         * already interacted - the Passport poll is the only caller. It is not a
         * progress display: the runner restores its own suite banner as soon as
         * the case ends, and the Output panel is the report.
         *
         * It used to be called from a dozen tests ("Unlocking X...", "Loading app
         * data...") and those were removed. Each message outlived the work it
         * described, so the stage usually showed a line that had nothing to do
         * with what the run was actually doing.
         */
        public function status(message:String):void {
            if (ui != null) {
                ui.setInfo(message);
            }
        }

        //==================== PRIVATE ====================

        /**
         * Renders a value for an assertion message.
         *
         * Worth the effort: the default toString() gives "[object Object]" for
         * anything structured, which turns a failed comparison into a message
         * that says nothing at all. Models and plain objects are shown as JSON
         * so the failure names the actual data.
         */
        private function describe(value:*):String {
            if (value === null) {
                return "null";
            }
            if (value === undefined) {
                return "undefined";
            }
            if (value is String) {
                return '"' + value + '"';
            }
            if (value is Boolean || value is Number || value is int || value is uint) {
                return String(value);
            }

            // Library models know how to serialise themselves, and their
            // toString() is usually a summary rather than the full state
            if (value is BaseObject) {
                try {
                    return (value as BaseObject).objectName + " " + (value as BaseObject).toJsonString();
                } catch (modelError:Error) {
                }
            }

            if (value is Array) {
                var list:Array = value as Array;
                try {
                    return "Array(" + list.length + ") " + NGJSON.stringify(list);
                } catch (arrayError:Error) {
                }
                return "Array(" + list.length + ")";
            }

            if (value is Function) {
                return "<function>";
            }

            try {
                return NGJSON.stringify(value);
            } catch (jsonError:Error) {
            }

            try {
                return String(value);
            } catch (e:Error) {
            }
            return "<unprintable>";
        }
    }
}
