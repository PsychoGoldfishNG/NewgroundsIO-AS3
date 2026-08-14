/**
 * NgioUnitTest
 *
 * Entry point for NgioUnitTest.fla. The .fla's first frame does:
 *
 *     import initiator.NgioUnitTest;
 *     initiator.NgioUnitTest.startTests(this);
 *
 * with its AS3 class paths set to ".;..\build" - so this file lives under
 * test/ and the library under build/.
 *
 * Everything this class does is wiring: find the three stage objects, hand them
 * to the harness, register the suites, and start the run. Results go to
 * trace(), which lands in the Flash IDE Output panel.
 */
package initiator {

    import flash.display.DisplayObject;
    import flash.display.InteractiveObject;
    import flash.display.MovieClip;
    import flash.text.TextField;

    import ngiotest.Reporter;
    import ngiotest.TestRunner;
    import ngiotest.TestUI;

    import ngiotest.suites.LiveAppDataSuite;
    import ngiotest.suites.LiveCloudSaveSuite;
    import ngiotest.suites.LiveCrossAppSuite;
    import ngiotest.suites.LiveGateSuite;
    import ngiotest.suites.LiveGatewaySuite;
    import ngiotest.suites.LiveLoaderSuite;
    import ngiotest.suites.LiveMedalSuite;
    import ngiotest.suites.LiveScoreBoardSuite;
    import ngiotest.suites.LiveSessionSuite;
    import ngiotest.suites.OfflineBaseObjectSuite;
    import ngiotest.suites.OfflineCryptoSuite;
    import ngiotest.suites.OfflineForeignGuardSuite;
    import ngiotest.suites.OfflineJsonSuite;
    import ngiotest.suites.OfflineModelSuite;
    import ngiotest.suites.OfflineObjectFactorySuite;
    import ngiotest.suites.OfflineWireFormatSuite;

    public class NgioUnitTest {

        /** The run in progress, kept alive for the length of the session */
        public static var instance:NgioUnitTest;

        //==================== ENTRY POINT ====================

        /**
         * Called from the .fla's first frame.
         *
         * @param caller The timeline holding infoText, inputButton and
         *               inputButtonLabel - normally `this`
         */
        public static function startTests(caller:MovieClip):void {
            if (instance != null) {
                trace("NgioUnitTest: already running, ignoring a second startTests() call");
                return;
            }

            instance = new NgioUnitTest(
                findTextField(caller, "infoText"),
                findButton(caller, "inputButton"),
                findTextField(caller, "inputButtonLabel")
            );
        }

        //==================== PROPERTIES ====================

        private var ui:TestUI;
        private var runner:TestRunner;

        //==================== CONSTRUCTOR ====================

        public function NgioUnitTest(infoText:TextField, inputButton:InteractiveObject, inputButtonLabel:TextField) {
            ui = new TestUI(infoText, inputButton, inputButtonLabel);
            ui.setInfo("Running tests...\n\nResults appear in the Output panel.");

            if (infoText == null) {
                trace("NgioUnitTest: WARNING - no 'infoText' field found on the stage. " +
                      "Progress messages will only appear in the Output panel.");
            }
            if (inputButton == null) {
                trace("NgioUnitTest: WARNING - no 'inputButton' found on the stage. " +
                      "Tests that need a click (Passport sign-in) will be skipped.");
            }

            runner = new TestRunner(ui);
            registerSuites();
            runner.run(onRunComplete);
        }

        //==================== SUITE REGISTRATION ====================

        /**
         * Order matters. Offline suites run first because they need nothing and
         * localise failures best. Among the live suites, Gateway proves basic
         * connectivity, Session establishes the login the rest depend on, and
         * App data fills the caches the medal/scoreboard/save suites read.
         */
        private function registerSuites():void {
            // --- offline: no network, no login ---
            runner.addSuite(new OfflineBaseObjectSuite());
            runner.addSuite(new OfflineObjectFactorySuite());
            runner.addSuite(new OfflineJsonSuite());
            runner.addSuite(new OfflineCryptoSuite());
            runner.addSuite(new OfflineWireFormatSuite());
            runner.addSuite(new OfflineModelSuite());
            runner.addSuite(new OfflineForeignGuardSuite());

            // --- live: real gateway ---
            runner.addSuite(new LiveGateSuite());
            runner.addSuite(new LiveGatewaySuite());
            runner.addSuite(new LiveSessionSuite());
            runner.addSuite(new LiveAppDataSuite());
            runner.addSuite(new LiveMedalSuite());
            runner.addSuite(new LiveScoreBoardSuite());
            runner.addSuite(new LiveCloudSaveSuite());
            // After the suites that populate the local caches, so it has
            // something real to prove a foreign read cannot disturb
            runner.addSuite(new LiveCrossAppSuite());
            runner.addSuite(new LiveLoaderSuite());
        }

        //==================== COMPLETION ====================

        private function onRunComplete(finishedRunner:TestRunner):void {
            if (finishedRunner.failedCount > 0) {
                Reporter.line("Scroll up for the [FAIL] lines - each one names the assertion that broke.");
            }
        }

        //==================== STAGE LOOKUP ====================

        /**
         * Fetch a TextField from the timeline by instance name.
         *
         * Returns null rather than throwing when the object is missing, so a
         * .fla with a partial stage still runs what it can.
         */
        private static function findTextField(caller:MovieClip, name:String):TextField {
            return findChild(caller, name) as TextField;
        }

        /**
         * Fetch the clickable control from the timeline by instance name.
         *
         * Typed as InteractiveObject, not MovieClip, because a symbol placed on
         * the stage with "Button" behaviour compiles to flash.display.SimpleButton -
         * and `as MovieClip` on a SimpleButton silently yields null, which would
         * disable every interactive test without an error. InteractiveObject is
         * the common ancestor of SimpleButton, MovieClip and Sprite, so the same
         * code works whichever symbol type the .fla uses.
         */
        private static function findButton(caller:MovieClip, name:String):InteractiveObject {
            return findChild(caller, name) as InteractiveObject;
        }

        private static function findChild(caller:MovieClip, name:String):DisplayObject {
            if (caller == null) {
                return null;
            }

            // Timeline instances are reachable both as named children and as
            // dynamic properties. Which one resolves depends on how the object
            // was placed, so try both before giving up.
            try {
                var child:DisplayObject = caller.getChildByName(name);
                if (child != null) {
                    return child;
                }
            } catch (e:Error) {
            }

            try {
                return caller[name] as DisplayObject;
            } catch (e:Error) {
            }

            return null;
        }
    }
}
