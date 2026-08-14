/**
 * OfflineJsonSuite
 *
 * NGJSON prefers the player's native JSON and falls back to a bundled
 * encoder/decoder when it is missing. Flash Player 11 introduced native JSON,
 * and the test .fla publishes to Flash Player 10 - so in the IDE these tests
 * exercise the fallback, while a SWF built for a newer player exercises the
 * native path. Both have to behave identically, which is what this suite
 * checks. The active implementation is reported as a note.
 */
package ngiotest.suites {

    import flash.utils.getDefinitionByName;

    import io.newgrounds.NGJSON;

    import ngiotest.TestContext;
    import ngiotest.TestSuite;

    public class OfflineJsonSuite extends TestSuite {

        override public function get suiteName():String {
            return "Offline / JSON";
        }

        override public function build():void {

            add("reports which implementation is active", function(t:TestContext):void {
                t.note("NGJSON is using the " + (hasNativeJSON() ? "native player" : "bundled fallback") + " implementation");
                t.done();
            });

            add("round-trips scalars", function(t:TestContext):void {
                assertRoundTrip(t, { s: "text" }, "string");
                assertRoundTrip(t, { n: 42 }, "integer");
                assertRoundTrip(t, { n: -17 }, "negative integer");
                assertRoundTrip(t, { n: 3.5 }, "float");
                assertRoundTrip(t, { b: true }, "true");
                assertRoundTrip(t, { b: false }, "false");
                t.done();
            });

            add("round-trips nested structures", function(t:TestContext):void {
                var source:Object = {
                    app_id: "1:abc",
                    execute: [
                        { component: "Medal.getList", parameters: {} },
                        { component: "ScoreBoard.getScores", parameters: { id: 1, limit: 10 } }
                    ]
                };

                var decoded:Object = NGJSON.parse(NGJSON.stringify(source));
                t.assertEquals("1:abc", decoded.app_id, "top-level string");
                t.assertEquals(2, (decoded.execute as Array).length, "array length");
                t.assertEquals("Medal.getList", decoded.execute[0].component, "nested string");
                t.assertEquals(10, decoded.execute[1].parameters.limit, "deeply nested number");
                t.done();
            });

            add("escapes strings correctly", function(t:TestContext):void {
                // Score tags and save data are free text, so an unescaped quote or
                // newline turns into a malformed request the gateway rejects.
                assertRoundTrip(t, { v: 'has "quotes"' }, "double quotes");
                assertRoundTrip(t, { v: "has \\ backslash" }, "backslash");
                assertRoundTrip(t, { v: "line1\nline2" }, "newline");
                assertRoundTrip(t, { v: "col1\tcol2" }, "tab");
                assertRoundTrip(t, { v: "carriage\rreturn" }, "carriage return");
                assertRoundTrip(t, { v: "" }, "empty string");
                t.done();
            });

            add("handles empty containers", function(t:TestContext):void {
                var decoded:Object = NGJSON.parse(NGJSON.stringify({ obj: {}, arr: [] }));
                t.assertNotNull(decoded.obj, "empty object survived");
                t.assertNotNull(decoded.arr, "empty array survived");
                t.assertEquals(0, (decoded.arr as Array).length, "array is empty");
                t.done();
            });

            add("encodes null", function(t:TestContext):void {
                var decoded:Object = NGJSON.parse(NGJSON.stringify({ v: null }));
                t.assertNull(decoded.v, "null survived");
                t.done();
            });

            add("parses whitespace-padded JSON", function(t:TestContext):void {
                var decoded:Object = NGJSON.parse('  {  "a" : 1 ,  "b" : [ 1 , 2 ]  }  ');
                t.assertEquals(1, decoded.a, "value past the whitespace");
                t.assertEquals(2, (decoded.b as Array).length, "array parsed");
                t.done();
            });

            add("parses unicode escapes", function(t:TestContext):void {
                var decoded:Object = NGJSON.parse('{"v":"caf\\u00e9"}');
                t.assertEquals("café", decoded.v, "\\u escape decoded");
                t.done();
            });

            add("parses exponent notation", function(t:TestContext):void {
                t.assertEquals(1000, NGJSON.parse('{"v":1e3}').v, "1e3");
                t.assertEquals(0.001, NGJSON.parse('{"v":1e-3}').v, "1e-3");
                t.assertEquals(-250, NGJSON.parse('{"v":-2.5e2}').v, "-2.5e2");
                t.done();
            });

            add("round-trips a large timestamp without precision loss", function(t:TestContext):void {
                // Unix timestamps in milliseconds exceed the 32-bit int range, so a
                // parser that reaches for int instead of Number silently truncates.
                var big:Number = 1767225600000;
                t.assertEquals(big, NGJSON.parse(NGJSON.stringify({ v: big })).v, "millisecond timestamp");
                t.done();
            });
        }

        //==================== HELPERS ====================

        private function assertRoundTrip(t:TestContext, source:Object, label:String):void {
            var decoded:Object = NGJSON.parse(NGJSON.stringify(source));
            for (var key:String in source) {
                t.assertStrictEquals(source[key], decoded[key], label);
            }
        }

        private function hasNativeJSON():Boolean {
            try {
                return getDefinitionByName("JSON") != null;
            } catch (e:Error) {
            }
            return false;
        }
    }
}
