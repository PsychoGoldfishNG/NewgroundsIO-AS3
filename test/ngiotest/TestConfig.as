/**
 * TestConfig
 *
 * Every knob the test suite exposes, in one place.
 *
 * The app credentials below belong to the unpublished "Newgrounds.io AS3 test"
 * project, which exists purely for this suite. They are safe to keep in the
 * repo. Do NOT replace them with credentials for a published game: the live
 * suite posts scores, unlocks medals and writes cloud saves.
 */
package ngiotest {

    import io.newgrounds.Core;

    public class TestConfig {

        //==================== APP CREDENTIALS ====================

        /** "Newgrounds.io AS3 test" - unpublished, viral mode, nothing blocked */
        public static const APP_ID:String = "61512:1uYiEl7d";

        /** AES-128 key for the app above */
        public static const ENCRYPTION_KEY:String = "1FjdwbrBGZ4oBZuMPhXqBQ==";

        /**
         * The test app deliberately has version control switched off, so there
         * is no "current version" to compare against and clientDeprecated
         * should always come back false.
         */
        public static const BUILD_VERSION:String = null;

        //==================== RUN CONTROL ====================

        /** Offline suites need no network and no login */
        public static const RUN_OFFLINE_TESTS:Boolean = true;

        /** Live suites talk to the real gateway */
        public static const RUN_LIVE_TESTS:Boolean = true;

        /**
         * Debug mode tells the gateway to validate and reply normally without
         * committing anything. That is what makes medal-unlock and score-post
         * tests repeatable: nothing has to be re-locked between runs.
         *
         * Set false only when deliberately verifying that writes persist, and
         * expect to re-lock medals on the server afterwards.
         */
        public static const USE_DEBUG_MODE:Boolean = true;

        /**
         * When true, the live run pauses and asks the user to sign in through
         * Passport. Set false to run only the tests that work for a guest;
         * everything needing a user then reports as skipped.
         */
        public static const REQUIRE_LOGIN:Boolean = true;

        /**
         * When true, the runner asks for a click before starting the live
         * suites, so the offline results can be read first (or live skipped).
         */
        public static const CONFIRM_BEFORE_LIVE:Boolean = true;

        //==================== APP CONTENT ====================

        /** The one custom event configured on the test app */
        public static const CUSTOM_EVENT:String = "ngio_unit_test";

        /**
         * The domain the test app's official and author urls are expected to
         * use.
         *
         * This is an assumption about THIS APP's configuration, not a rule of
         * the API. Those two urls are generated when a project is created,
         * using the values of whichever environment created it, and an author
         * can edit them afterwards to point anywhere at all. Change this if the
         * test app's urls are ever customised, and change it alongside
         * Core.GATEWAY_URL when testing against a different environment.
         *
         * Deliberately not applied to loadMoreGames or loadNewgrounds: those are
         * hardcoded server-side to production newgrounds.com by design, on every
         * environment.
         */
        public static const SITE_DOMAIN:String = "newgrounds.com";

        /** The one custom referral configured on the test app */
        public static const CUSTOM_REFERRAL:String = "my_referral";

        /** Medals configured on the test app, used to sanity-check Medal.getList */
        public static const EXPECTED_MEDAL_COUNT:int = 3;

        /** Scoreboards configured on the test app (one standard, one incremental) */
        public static const EXPECTED_SCOREBOARD_COUNT:int = 2;

        /** Cloud save slots configured on the test app */
        public static const EXPECTED_SAVE_SLOT_COUNT:int = 10;

        /** Save slot the CloudSave suite writes raw text to */
        public static const TEST_SAVE_SLOT_ID:int = 1;

        /**
         * A second scratch slot, used by the structured round-trip test.
         *
         * It needs its own slot rather than reusing the one above. The save-data
         * url the gateway returns is cache-busted only to the second
         * (...sav?1786656297), so two writes to the same slot inside one second
         * produce byte-identical urls - and the player then serves the first
         * body from cache for the second read. That made the round-trip test
         * fail against the *previous* test's payload. Separate slots mean
         * separate filenames, so the tests cannot alias each other.
         */
        public static const TEST_SAVE_SLOT_ID_ALT:int = 2;

        //==================== FAILURE DIAGNOSTICS ====================

        /**
         * When true, a failing test prints the raw JSON exchanged with the
         * gateway during that test. Passing tests never print traffic, so the
         * report stays readable.
         *
         * Encrypted `secure` payloads are decrypted for display using
         * ENCRYPTION_KEY, so a failed medal unlock shows what the server
         * actually received.
         */
        public static const CAPTURE_PACKETS_ON_FAILURE:Boolean = true;

        /**
         * Trace every packet as it happens, pass or fail, via
         * Core.debugNetworkCalls. Noisy and interleaved with test output - for
         * when a failure is not reproducing and you want the full picture.
         */
        public static const TRACE_ALL_PACKETS:Boolean = false;

        /** Indent captured JSON. Off gives compact one-line packets. */
        public static const PRETTY_PRINT_PACKETS:Boolean = true;

        /** Cap on how much of a single packet is printed. 0 means no limit. */
        public static const MAX_CAPTURED_PACKET_CHARS:int = 4000;

        /** How many packets to retain per test before dropping older ones */
        public static const MAX_CAPTURED_PACKETS:int = 12;

        //==================== CROSS-APP ACCESS ====================

        /**
         * "Newgrounds.IO test" - a separate app that has granted this one
         * read-only access via the app_id parameter on Medal.getList,
         * ScoreBoard.getScores, CloudSave.loadSlot and CloudSave.loadSlots.
         *
         * Used to prove two things: that cross-app reads work, and - more
         * importantly - that the data they return never lands in this app's
         * AppState caches.
         */
        public static const READABLE_FOREIGN_APP_ID:String = "39685:NJ1KkPGb";

        /**
         * A scoreboard belonging to READABLE_FOREIGN_APP_ID.
         *
         * It has to be hardcoded: ScoreBoard.getBoards does not accept an
         * app_id, so there is no supported way to discover another app's board
         * ids at runtime.
         */
        public static const READABLE_FOREIGN_SCOREBOARD_ID:int = 5853;

        /**
         * An app that has NOT granted this one access. The AS2 test app is
         * documented as not sharing with anyone, so a read should be refused.
         */
        public static const UNREADABLE_FOREIGN_APP_ID:String = "59735:NNSlBwZV";

        //==================== CLAMPING PROBE ====================

        /**
         * Whether the gateway under test clamps score limits into 1-100.
         *
         * FALSE for production as of 2026-08-14: it passes `limit` through
         * unchanged, and `limit: 0` returns an empty list rather than one score.
         * The clamp exists on the development branch and has not shipped.
         *
         * When false the three clamp probes still RUN and still report exactly
         * what the server did - they just record it as a note instead of failing,
         * so an unshipped feature does not sit as a permanent red mark. Flip it to
         * true once the clamp deploys, and they become assertions again.
         *
         * Worth flipping deliberately rather than deleting the tests: the rule the
         * library enforces (reject a limit outside 1-100) is written against the
         * clamped behaviour, so it is worth knowing the day it changes.
         */
        public static const SERVER_CLAMPS_SCORE_LIMIT:Boolean = false;



        /**
         * An app and board known to hold well over 100 scores, read cross-app.
         *
         * The clamp tests prove the LIMIT was honoured from the result's echo on
         * any board. Proving the server actually stopped at 100 ROWS needs a board
         * with more than 100 rows in it - "at most 100" is satisfied trivially by
         * a board holding two.
         *
         * EMPTY BY DEFAULT, deliberately. With no board configured the tests fall
         * back to a local one, check the echo, and say in their note that the row
         * cap is unproven - so a green run never claims more than it verified.
         * Setting this to a board that turns out to hold FEWER than 100 rows would
         * fail the run for a reason that has nothing to do with the library.
         *
         * To enable it: pick a board you know is full, and make sure its app has
         * granted read access to APP_ID. Verified working against a board with
         * enough rows - limit 500 came back as limit 100 with exactly 100 rows.
         */
        public static const SCORE_RICH_APP_ID:String = "";

        /** A board on SCORE_RICH_APP_ID holding more than 100 scores */
        public static const SCORE_RICH_BOARD_ID:int = 0;

        //==================== TIMING ====================

        /**
         * Pause between LIVE test cases, in milliseconds. 0 disables pacing.
         *
         * READ THIS BEFORE TRUSTING IT. The gateway limits a COUNT of requests
         * per window, not a rate, and a full run lands close to that count.
         * Pacing cannot help: spreading the cases out makes the run longer
         * without making it smaller, and the count is the only thing measured.
         *
         * Kept anyway, because it costs little and being gentle with someone
         * else's server is the right default for a test suite that exists to
         * hammer it. Setting it to 0 is entirely defensible.
         *
         * Offline suites are never paced - they make no requests, and slowing
         * them would only make the suite feel broken.
         */
        public static const LIVE_TEST_PACING_MS:int = 100;

        /**
         * Pause before each Loader.* case specifically. -1 uses the value above.
         *
         * Back to -1 because the Loader suite turned out not to be special. It
         * was slowed to 2000 while the 429s all appeared to land there; moving
         * the suite earlier in the run showed those failures follow the RUN's
         * request count, not the component - see the rate limiting section of
         * README.md. The mechanism it was added to probe does not exist.
         *
         * Left in place rather than deleted: TestSuite.pacingMs is a reasonable
         * thing to have, and this is the obvious worked example of using it.
         */
        public static const LOADER_PACING_MS:int = -1;

        /** Default watchdog for a single test */
        public static const TEST_TIMEOUT_MS:int = 20000;

        /** Watchdog for tests that wait on a human (Passport sign-in, medal re-lock) */
        public static const INTERACTIVE_TIMEOUT_MS:int = 300000;

        /** How often to re-check the session while waiting for Passport */
        public static const SESSION_POLL_INTERVAL_MS:int = 4000;

        //==================== DERIVED ====================

        /**
         * The gateway the library is compiled against. Read from Core rather
         * than duplicated, so switching Core.GATEWAY_URL to a development
         * host shows up in the report instead of silently changing what the
         * suite exercised.
         */
        public static function gatewayUrl():String {
            return Core.GATEWAY_URL;
        }
    }
}
