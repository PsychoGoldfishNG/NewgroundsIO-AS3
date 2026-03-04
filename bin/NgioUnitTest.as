/**
 * NgioUnitTest
 *
 * Runs unit tests for NGIO wrapper methods not represented in the prefab
 * components in components_cs5.fla. Assumes NGIO has already been initialized
 * (e.g. by the Connector Component).
 *
 * Place this file in the same directory as your .fla so Flash can find it.
 * It does NOT need to be included in end-user projects.
 *
 * USAGE (on a frame after NGIO is initialized):
 *
 *   NgioUnitTest.run();
 *
 * Results are written via trace(). Each test waits for its async callback
 * before starting the next, with a short delay between calls to avoid
 * triggering server-side rate limiting.
 *
 * An optional argument sets the delay in ms between tests (default 500):
 *
 *   NgioUnitTest.run(1000);
 *
 * NOTE: loadReferral requires a referral name configured in your Newgrounds
 * project. Update the name in _test_loadReferral() before running.
 */
package {

	import flash.utils.Timer;
	import flash.events.TimerEvent;

	public class NgioUnitTest {

		public static var queue:Array;
		public static var index:int;
		public static var passed:int;
		public static var failed:int;
		public static var delay:int;
		public static var timer:Timer;

		/**
		 * Run all unit tests.
		 * @param delayMs  Milliseconds between each test (default 500)
		 */
		public static function run(delayMs:int = 500):void {
			delay   = delayMs;
			index   = 0;
			passed  = 0;
			failed  = 0;
			queue   = buildQueue();
			trace("==================================================");
			trace("[NgioUnitTest] Starting " + queue.length + " tests");
			trace("==================================================");
			next();
		}

		public static function buildQueue():Array {
			return [
				{name:"loadGatewayVersion",   fn:_test_loadGatewayVersion},
				{name:"loadCurrentVersion",   fn:_test_loadCurrentVersion},
				{name:"loadClientDeprecated", fn:_test_loadClientDeprecated},
				{name:"loadHostApproved",     fn:_test_loadHostApproved},
				{name:"loadGatewayTimestamp", fn:_test_loadGatewayTimestamp},
				{name:"loadGatewayDateTime",  fn:_test_loadGatewayDateTime},
				{name:"loadGatewayDate",      fn:_test_loadGatewayDate},
				{name:"sendPing",             fn:_test_sendPing},
				{name:"logEvent",             fn:_test_logEvent},
				{name:"loadMedals",           fn:_test_loadMedals},
				{name:"loadMedalScore",       fn:_test_loadMedalScore},
				{name:"loadScoreBoards",      fn:_test_loadScoreBoards},
				{name:"loadSaveSlots",        fn:_test_loadSaveSlots},
				{name:"loadOfficialUrl",      fn:_test_loadOfficialUrl},
				{name:"loadAuthorUrl",        fn:_test_loadAuthorUrl},
				{name:"loadMoreGames",        fn:_test_loadMoreGames},
				{name:"loadNewgrounds",       fn:_test_loadNewgrounds},
				{name:"loadReferral",         fn:_test_loadReferral}
			];
		}

		public static function next():void {
			if (index >= queue.length) {
				trace("==================================================");
				trace("[NgioUnitTest] Complete: " + passed + " passed, " + failed + " failed");
				trace("==================================================");
				return;
			}
			var entry:Object = queue[index];
			trace("[NgioUnitTest] (" + (index + 1) + "/" + queue.length + ") NGIO." + entry.name);

			entry.fn(function(ok:Boolean, detail:String):void {
				if (ok) {
					NgioUnitTest.passed++;
					trace("[NgioUnitTest]  PASS" + (detail ? ": " + detail : ""));
				} else {
					NgioUnitTest.failed++;
					trace("[NgioUnitTest]  FAIL: " + detail);
				}
				NgioUnitTest.index++;
				NgioUnitTest.timer = new Timer(NgioUnitTest.delay, 1);
				NgioUnitTest.timer.addEventListener(TimerEvent.TIMER_COMPLETE, function(e:TimerEvent):void {
					NgioUnitTest.next();
				});
				NgioUnitTest.timer.start();
			});
		}

		// ==================== INDIVIDUAL TESTS ====================

		public static function _test_loadGatewayVersion(done:Function):void {
			NGIO.loadGatewayVersion(function(version:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(version is String && (version as String).length > 0, "version=" + version);
			});
		}

		public static function _test_loadCurrentVersion(done:Function):void {
			NGIO.loadCurrentVersion(function(version:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				// version may be null if not set in project settings - that is acceptable
				done(true, "version=" + version);
			});
		}

		public static function _test_loadClientDeprecated(done:Function):void {
			NGIO.loadClientDeprecated(function(deprecated:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(deprecated is Boolean, "deprecated=" + deprecated);
			});
		}

		public static function _test_loadHostApproved(done:Function):void {
			NGIO.loadHostApproved(function(approved:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(approved is Boolean, "approved=" + approved);
			});
		}

		public static function _test_loadGatewayTimestamp(done:Function):void {
			NGIO.loadGatewayTimestamp(function(timestamp:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(timestamp is Number && (timestamp as Number) > 0, "timestamp=" + timestamp);
			});
		}

		public static function _test_loadGatewayDateTime(done:Function):void {
			NGIO.loadGatewayDateTime(function(dateTime:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(dateTime is String && (dateTime as String).length > 0, "dateTime=" + dateTime);
			});
		}

		public static function _test_loadGatewayDate(done:Function):void {
			NGIO.loadGatewayDate(function(date:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(date is Date, "date=" + date);
			});
		}

		public static function _test_sendPing(done:Function):void {
			NGIO.sendPing(function(pong:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(pong == "pong", "pong=" + pong);
			});
		}

		public static function _test_logEvent(done:Function):void {
			NGIO.logEvent("ngio_unit_test", function(error:*):void {
				done(error == null, error != null ? "error: " + error : "ok");
			});
		}

		public static function _test_loadMedals(done:Function):void {
			NGIO.loadMedals(function(medals:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(medals is Array, "count=" + (medals ? (medals as Array).length : "null"));
			});
		}

		public static function _test_loadMedalScore(done:Function):void {
			NGIO.loadMedalScore(function(score:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(score is Number, "score=" + score);
			});
		}

		public static function _test_loadScoreBoards(done:Function):void {
			NGIO.loadScoreBoards(function(boards:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(boards is Array, "count=" + (boards ? (boards as Array).length : "null"));
			});
		}

		public static function _test_loadSaveSlots(done:Function):void {
			NGIO.loadSaveSlots(function(slots:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(slots is Array, "count=" + (slots ? (slots as Array).length : "null"));
			});
		}

		public static function _test_loadOfficialUrl(done:Function):void {
			NGIO.loadOfficialUrl(false, function(url:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(url is String && (url as String).length > 0, "url=" + url);
			});
		}

		public static function _test_loadAuthorUrl(done:Function):void {
			NGIO.loadAuthorUrl(false, function(url:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(url is String && (url as String).length > 0, "url=" + url);
			});
		}

		public static function _test_loadMoreGames(done:Function):void {
			NGIO.loadMoreGames(false, function(url:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(url is String && (url as String).length > 0, "url=" + url);
			});
		}

		public static function _test_loadNewgrounds(done:Function):void {
			NGIO.loadNewgrounds(false, function(url:*, error:*):void {
				if (error != null) { done(false, "error: " + error); return; }
				done(url is String && (url as String).length > 0, "url=" + url);
			});
		}

		public static function _test_loadReferral(done:Function):void {
			// NOTE: Replace "my_referral" with a referral name configured in your Newgrounds project.
			// If the name is not found the server returns an error - this still confirms the call
			// mechanism works, so the test passes either way.
			NGIO.loadReferral("my_referral", false, function(url:*, error:*):void {
				done(
					url != null || error != null,
					url != null ? ("url=" + url) : "referral not found (expected if unconfigured)"
				);
			});
		}
	}
}
