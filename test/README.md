# NewgroundsIO-AS3 test suite

171 tests across 16 suites, covering the class library in `../build`. It does
**not** test the drag-and-drop components in `../src` — only the code a
developer talks to directly (`NGIO`, `Core`, the models, the helpers).

## Running it

Open **`NgioUnitTest.fla`** in Flash Professional (CS5 or newer) and press
**Ctrl+Enter**. Results appear in the **Output** panel.

That's it. The .fla's first frame is just:

```actionscript
import initiator.NgioUnitTest;
initiator.NgioUnitTest.startTests(this);
```

with AS3 class paths set to `.` and `..\build`.

### Before the first live run

Publish Settings → Flash → **Local playback security** must be
**"Access network only"**. The .fla currently ships set to *Access local files
only*, which silently blocks every gateway request when you test from the IDE.
The offline suites don't care; the live ones will all fail without it.

### What you'll be asked to do

The run is unattended until the live tests start. Then the on-stage button
appears twice:

1. **"Run live tests"** — a confirmation, so you can read the offline results
   first. Ignore it for 90 seconds and the live suites are skipped cleanly.
2. **"Open Newgrounds sign-in"** — opens Passport in your browser. Approve the
   app and come back; the suite polls until it sees the session and carries on
   by itself.

You do **not** need to re-lock medals between runs. `TestConfig.USE_DEBUG_MODE`
is on by default, so the gateway validates unlocks and score posts normally
without committing them.

## Layout

```
test/
  NgioUnitTest.fla            the entry point you open
  initiator/NgioUnitTest.as   wiring: finds the stage objects, registers suites
  TestRunnerStandalone.as     alternate entry point for command-line builds
  build-tests.ps1             optional mxmlc build (see below)
  ngiotest/
    TestConfig.as             every knob: credentials, toggles, timeouts
    TestRunner.as             sequential async runner + watchdog
    TestContext.as            assertions, done(), prompt()
    TestSuite.as / TestCase.as
    TestUI.as                 drives infoText / inputButton / inputButtonLabel
    Reporter.as               output formatting
    LiveSuite.as              base for gateway suites; shared NGIO.init()
    suites/                   the tests themselves
```

## The suites

Registration order in `initiator/NgioUnitTest.as` is deliberate: offline first
(fastest, most precise failures), then gateway connectivity, then login, then
everything that depends on a session.

### Offline — no network, no login (95 tests)

| Suite | What it pins down |
|---|---|
| `OfflineBaseObjectSuite` | Import/export for every model: type coercion, defaults on omitted fields, nested and `array-of-X` casting, error payloads, required-property validation |
| `OfflineObjectFactorySuite` | Walks the full inventory — 11 objects, 25 components, 25 results — so a model added to the codebase but not to the factory's switch fails here rather than silently returning null |
| `OfflineJsonSuite` | `NGJSON` round-trips: escapes, unicode, exponents, big timestamps. Reports whether the native or bundled parser is active |
| `OfflineCryptoSuite` | **Decrypts what `Core` encrypted**, independently, using the same as3crypto primitives the server uses — AES-128-CBC, PKCS5, prepended IV, Base64. Also covers block-boundary padding, UTF-8, IV freshness, and the key not being consumed between calls |
| `OfflineWireFormatSuite` | Builds the exact gateway envelope and reads canned server replies through the real importer. Confirms secure components serialise to `{secure:...}` only, `debug` is omitted when off, unknown result types are skipped, and results sync into `AppState` |
| `OfflineModelSuite` | Hand-written model behaviour: `toString`, session clearing, `ScoreBoard.getScores` argument validation, `Errors` codes, `AppState` status derivation |
| `OfflineForeignGuardSuite` | The write guards on objects loaded from another app. Confirms `unlock`, `postScore`, `saveData`, `saveDataRaw` and `clearData` all throw on a foreign object — and that the reads (`loadDataRaw`, `getScores`) and every local object are left alone |

### Live — real gateway (76 tests)

| Suite | Needs login? | Notes |
|---|---|---|
| `LiveGateSuite` | no | The confirmation prompt |
| `LiveGatewaySuite` | no | ping, version, server time, host license, custom event. **Read this first when a live run goes wrong** — if ping fails, nothing below matters |
| `LiveSessionSuite` | — | Establishes the session; contains the Passport flow |
| `LiveAppDataSuite` | partly | Batch-loads medals/scoreboards/save slots, checks counts against `TestConfig`, verifies lookup-by-id returns cached instances |
| `LiveMedalSuite` | yes | The encrypted `Medal.unlock` path, repeat unlocks, unknown-id rejection |
| `LiveScoreBoardSuite` | yes | `postScore` (also encrypted), plus every documented `getScores` filter |
| `LiveCloudSaveSuite` | yes | Write, read back over HTTP, structured round-trip, clear |
| `LiveCrossAppSuite` | partly | Reads another app's data via the `app_id` parameter, proves it cannot reach this app's caches, and checks that a foreign board forwards its `app_id` (and accepts a `social` filter) on reads while a foreign medal refuses to unlock |
| `LiveLoaderSuite` | no | Resolves all five Loader URLs using the non-redirect form, so it doesn't open browser tabs |

Tests needing a user report `[SKIP]` rather than `[FAIL]` when you run as a
guest, so a guest-only run still reads cleanly.

## Configuration

Everything lives in `ngiotest/TestConfig.as`.

| Setting | Default | Effect |
|---|---|---|
| `RUN_OFFLINE_TESTS` | `true` | |
| `RUN_LIVE_TESTS` | `true` | `false` drops all live suites |
| `USE_DEBUG_MODE` | `true` | Gateway validates without committing. Turn off only to verify persistence — then expect to re-lock medals on the server |
| `REQUIRE_LOGIN` | `true` | `false` skips the Passport prompt and everything needing a user |
| `CONFIRM_BEFORE_LIVE` | `true` | `false` goes straight online |
| `APP_ID` / `ENCRYPTION_KEY` | AS3 test app | Unpublished app `61512:1uYiEl7d`, used only for this suite |
| `TEST_SAVE_SLOT_ID` | `1` | Cloud save tests write here and clear it afterwards |

The expected counts (`EXPECTED_MEDAL_COUNT` and friends) are asserted against,
so if the test app's configuration changes on Newgrounds, update them here.

### Testing against a development gateway

`Core.GATEWAY_URL` is a `const` in `../build/io/newgrounds/Core.as`. Point it at
a development host, run, then revert. The runner prints the gateway it's using
in its header, so the report always records which server produced it — no
development hostname is committed anywhere in this suite.

## Reading the output

```
--- Offline / Encryption ==========================================
  [PASS] encryptData() output decrypts back to the original text  (3 assertions)
  [FAIL] uses a fresh IV for every call
         two encryptions of the same text differ -- expected anything but <...>
  [SKIP] posts a score -- needs a signed-in user
         . gateway version 3.0.0
```

Lines beginning `.` are notes — values pulled from the server that are worth
eyeballing but aren't assertions. The summary at the end lists every failed
test by name.

## Debugging a failure

**A failing live test prints the JSON it exchanged with the gateway**, right
under the failure:

```
  [FAIL] unlocks a medal
         unlock accepted by the server -- gateway returned [202] Requested Medal does not exist...
         --- gateway traffic for this test ---
         | --- REQUEST ---
         | {
         |   "app_id": "61512:1uYiEl7d",
         |   "debug": true,
         |   "execute": {
         |     "secure": "Ux9k2b...==",
         |     "secure (decrypted by the test suite)": {
         |       "component": "Medal.unlock",
         |       "parameters": { "id": 0 }
         |     }
         |   },
         |   "session_id": "..."
         | }
         | --- RESPONSE ---
         | { "success": true, "result": { ... } }
         --- end traffic ---
```

Three things make this useful:

- **Only failures print traffic.** Passing tests stay quiet, and the log is
  cleared before each test, so you see only the exchanges that test caused.
- **Encrypted payloads are decrypted.** `Medal.unlock` and `ScoreBoard.postScore`
  go out as an opaque `secure` blob — normally the interesting half of a failed
  unlock is unreadable. The suite holds the key, so it shows the plaintext the
  server would have seen. In the example above, that immediately reveals the
  real bug: `"id": 0`, not a 202 problem at all.
- **Non-JSON responses print verbatim**, which is what you want when the server
  returns an HTML error page instead of JSON.

Offline failures print no traffic (they make no requests), but assertion
messages render models and objects as JSON rather than `[object Object]`, so
the expected/actual comparison names the actual data.

### Knobs

| `TestConfig` setting | Default | Effect |
|---|---|---|
| `CAPTURE_PACKETS_ON_FAILURE` | `true` | Attach traffic to failing tests |
| `TRACE_ALL_PACKETS` | `false` | Trace every packet as it happens, pass or fail (`Core.debugNetworkCalls`). Noisy, but useful when a failure won't reproduce |
| `PRETTY_PRINT_PACKETS` | `true` | Indent captured JSON; off gives one-line packets |
| `MAX_CAPTURED_PACKET_CHARS` | `4000` | Per-packet truncation. Raise it for full medal lists; `0` disables |
| `MAX_CAPTURED_PACKETS` | `12` | Packets retained per test |

### The library hook this relies on

Capturing traffic needed one small addition to the library — `Core` previously
only had `debugNetworkCalls`, which traces and nothing else:

- `io/newgrounds/Core.as` — new `networkObserver:Function` property and a
  `reportNetworkActivity()` method
- `io/newgrounds/helpers/CoreTransportHelper.as` — calls it at the seven points
  that already honoured `debugNetworkCalls`

It is inert unless something attaches an observer, and independent of
`debugNetworkCalls`. It is also useful outside the tests — a game can pipe
gateway packets into its own logger with it. If you'd rather not carry it,
reverting those two files just means `CAPTURE_PACKETS_ON_FAILURE` has nothing
to record; nothing else in the suite depends on it.

## Writing a test

```actionscript
add("does the thing", function(t:TestContext):void {
    t.assertEquals(expected, actual, "what should be true");
    t.done();                       // required, sync or async
});
```

Tests are async by default — the runner waits for `done()` and applies a
20-second watchdog (`TestConfig.TEST_TIMEOUT_MS`). For something slower, or
something that waits on a person, use `addSlow(name, timeoutMs, fn)`. To ask
the user for something, use `t.prompt(message, buttonLabel, handler)`.

Register the suite in `initiator/NgioUnitTest.as`.

## Command-line build (optional)

```powershell
.\build-tests.ps1
```

Compiles `TestRunnerStandalone.as`, which builds the same three controls in code
and calls the same entry point. Needs the Apache Flex SDK; it borrows
`playerglobal.swc` from a Flash CS5.x install so it targets the same player the
.fla does. Output goes to `trace()`, so you need the **debug** player and
`mm.cfg` with `TraceOutputFileEnable=1` to read it — which is exactly why the
.fla route is the recommended one.

## Notes from building this

Things worth knowing that aren't obvious from the code:

- **`inputButton` is a `SimpleButton`, not a `MovieClip`.** The previous
  initiator did `caller["inputButton"] as MovieClip`, which yields `null` for a
  button symbol — every interactive test would have been silently disabled. The
  lookup is now typed `InteractiveObject`, which covers `SimpleButton`,
  `MovieClip` and `Sprite` alike.
- **`inputButtonLabel` sits over `inputButton` and eats clicks**, because a
  `TextField` is an `InteractiveObject` in its own right. `TestUI` listens on
  both objects, so a click anywhere on the label or the button works, whatever
  the .fla's field settings are.
- **The .fla publishes to Flash Player 10**, which predates native `JSON`, so in
  the IDE `NGJSON` runs its bundled fallback. `OfflineJsonSuite` reports which
  implementation is active and asserts identical behaviour either way.
- **`AppState`'s constructor restores a saved session** from local storage.
  Offline suites build their own `AppState` and blank the session, so results
  don't depend on whether a previous run logged in.
- **`castToExpectedType`'s `'string'`/`'number'`/`'boolean'` branches are
  unreachable** through the generated models — every `castTypes` map in the
  library contains only object and `array-of-object` entries. Type coercion
  happens via typed-property assignment instead, which is what the suite tests.
- **Cross-app reads are a real isolation hazard.** Four components accept an
  `app_id` (`Medal.getList`, `ScoreBoard.getScores`, `CloudSave.loadSlot`,
  `CloudSave.loadSlots`), letting an approved app read a *different* app's data.
  Their results echo the source id back, and `AppState` now refuses to cache
  anything carrying a foreign one — without that, reading another app's medal
  list replaced the local list wholesale and marked it loaded, so
  `NGIO.getMedals()` returned the wrong game's medals.
- **`NGIO.loadExternal*` is the supported route.** `loadExternalMedals`,
  `loadExternalScores`, `loadExternalSaveSlots` and `loadExternalSaveSlot` hand
  results straight to the caller and cache nothing. `loadMedals()` and friends
  still take no `app_id`, deliberately — they exist to fill the caches, so a
  foreign variant would need a second cache keyed by app id and an app id
  argument on every reader.
- **`ScoreBoard.getBoards` does not accept `app_id`**, so there is no supported
  way to discover another app's board ids — you have to know one already, which
  is why `TestConfig.READABLE_FOREIGN_SCOREBOARD_ID` is hardcoded.
- **Objects returned by a cross-app read carry a live `core` pointing at *this*
  app**, so every write method now refuses them. `Medal.unlock`,
  `ScoreBoard.postScore`, `SaveSlot.saveData`, `saveDataRaw` and `clearData`
  throw when `isForeign()` is true. Reads are untouched: `SaveSlot.loadDataRaw`
  fetches an absolute URL, and `ScoreBoard.getScores` forwards the `app_id` the
  board came with.
- **The `SaveSlot` guards prevent data loss, not just a confusing error.** Medal
  and scoreboard ids are globally unique, so an unguarded write there is merely
  rejected (202 / 203). `SaveSlot.id` is a per-app *slot number* and every app
  has a slot 1, so an unguarded write through a foreign slot **succeeds** — it
  overwrites your own save. `OfflineForeignGuardSuite` covers this specifically.

## Status

**155 of the 171 tests are confirmed passing**, run from `NgioUnitTest.fla` in
the Flash IDE against the live gateway with a signed-in user. The 16 added
afterwards for the foreign-object write guards and cross-app `social` reads —
`OfflineForeignGuardSuite`, plus five live cross-app cases — are compile-clean but
have not been run yet.

The whole suite compiles clean under `-strict=true` against Flash Player 10.2.

Three bugs were found by the first full run and are fixed:

| Found | Where |
|---|---|
| Null dereference on any failed component that returns no payload — crashed the response import, replaced the server's real error with a generic 505, and in a batch silently dropped every result after it | `AppStateResultUpdateHelper`, `AppState.finalizeSessionPersistenceState` |
| Cross-app reads overwrote the local `AppState` caches, so `getMedals()` could return another app's medals | `AppStateResultUpdateHelper.isForeignAppResult()` |
| Two test bugs of my own: a medal-value assertion that rejected legitimate 0-point medals, and a cloud save round-trip that read a cached body because two writes landed in the same second and produced identical URLs | `LiveAppDataSuite`, `LiveCloudSaveSuite` |

Both library fixes carry regression tests, and both were propagated to
`AppState.pseudo` in the model generator and through to the wiki.

Note for anyone re-running from a command line: the Flash Player debugger on the
machine this was written on refuses to execute any SWF passed as an argument, so
`trace()` output cannot be captured that way. The IDE route is the one that
works.
