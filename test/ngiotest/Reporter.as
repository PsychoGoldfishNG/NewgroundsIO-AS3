/**
 * Reporter
 *
 * All test output funnels through here so the formatting stays consistent and
 * there is exactly one place to change if the output ever needs to go
 * somewhere other than trace().
 *
 * Output is plain ASCII on purpose - the Flash IDE Output panel and
 * flashlog.txt are not reliably UTF-8, and tick/cross glyphs come out as
 * mojibake often enough to make a report hard to read.
 */
package ngiotest {

    public class Reporter {

        /** Width of the ==== rules, chosen to fit the Output panel without wrapping */
        private static const RULE_WIDTH:int = 66;

        /**
         * Optional extra destination for every emitted line, as function(line:String):void.
         *
         * trace() always fires; this is in addition. Set it when the Output
         * panel is not available - to mirror the report into an on-screen field,
         * push it somewhere from an AIR build, or capture it from a test rig.
         */
        public static var sink:Function = null;

        /**
         * Emit a banner: rule, title, rule.
         */
        public static function header(title:String):void {
            rule();
            emit(title);
            rule();
        }

        /**
         * Start a new suite section.
         */
        public static function suite(name:String):void {
            emit("");
            emit("--- " + name + " " + dashes(RULE_WIDTH - 5 - name.length));
        }

        public static function pass(name:String, assertions:int):void {
            emit("  [PASS] " + name + assertionSuffix(assertions));
        }

        /**
         * Report a failure plus every assertion message that produced it.
         */
        public static function fail(name:String, messages:Array):void {
            emit("  [FAIL] " + name);
            for each (var message:String in messages) {
                emit("         " + message);
            }
        }

        /**
         * Print the gateway traffic captured during a failing test, indented
         * under the failure it belongs to.
         */
        public static function packets(lines:Array):void {
            if (lines == null || lines.length == 0) {
                return;
            }

            emit("         --- gateway traffic for this test ---");
            for each (var line:String in lines) {
                emit("         | " + line);
            }
            emit("         --- end traffic ---");
        }

        public static function skip(name:String, reason:String):void {
            emit("  [SKIP] " + name + ((reason != null && reason.length > 0) ? " -- " + reason : ""));
        }

        /**
         * A value a test wanted surfaced in the log (server versions, user names).
         */
        public static function note(message:String):void {
            emit("         . " + message);
        }

        public static function line(message:String):void {
            emit(message);
        }

        public static function blank():void {
            emit("");
        }

        public static function rule():void {
            emit(dashes(RULE_WIDTH));
        }

        //==================== PRIVATE ====================

        /**
         * The single exit point for every line of output.
         */
        private static function emit(text:String):void {
            trace(text);

            if (sink != null) {
                try {
                    sink.call(null, text);
                } catch (e:Error) {
                    // A broken sink must never take the test run down with it
                }
            }
        }

        private static function assertionSuffix(assertions:int):String {
            if (assertions <= 0) {
                return "";
            }
            return "  (" + assertions + (assertions == 1 ? " assertion)" : " assertions)");
        }

        private static function dashes(count:int):String {
            var text:String = "";
            for (var i:int = 0; i < count; i++) {
                text += "=";
            }
            return text;
        }
    }
}
