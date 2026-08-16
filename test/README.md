# NewgroundsIO-AS3 test suite

201 tests across 19 suites — 203 across 20 when a remembered login is found and
`LiveSignOutSuite` joins the run. Covers the class library in `../build`. It does
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
                              (+ the optional inputButton2 / inputButtonLabel2)
    Reporter.as               output formatting
    LiveSuite.as              base for gateway suites; shared NGIO.init()
    suites/                   the tests themselves
```

## The suites

Registration order in `initiator/NgioUnitTest.as` is deliberate: offline first
(fastest, most precise failures), then gateway connectivity, then login, then
everything that depends on a session.

### Offline — no network, no login (112 tests)

| Suite | What it pins down |
|---|---|
| `OfflineBaseObjectSuite` | Import/export for every model: type coercion, defaults on omitted fields, nested and `array-of-X` casting, error payloads, required-property validation |
| `OfflineObjectFactorySuite` | Walks the full inventory — 11 objects, 25 components, 25 results — so a model added to the codebase but not to the factory's switch fails here rather than silently returning null |
| `OfflineJsonSuite` | `NGJSON` round-trips: escapes, unicode, exponents, big timestamps. Reports whether the native or bundled parser is active. Also pins the parser's **strictness** — an HTML error page or trailing garbage must throw, not parse |
| `OfflineCryptoSuite` | **Decrypts what `Core` encrypted**, independently, using the same as3crypto primitives the server uses — AES-128-CBC, PKCS5, prepended IV, Base64. Also covers block-boundary padding, UTF-8, IV freshness, and the key not being consumed between calls |
| `OfflineWireFormatSuite` | Builds the exact gateway envelope and reads canned server replies through the real importer. Confirms secure components serialise to `{secure:...}` only, `debug` is omitted when off, unknown result types are skipped, and results sync into `AppState` |
| `OfflineModelSuite` | Hand-written model behaviour: `toString`, session clearing, `ScoreBoard.getScores` argument validation, `Errors` codes, `AppState` status derivation |
| `OfflineForeignGuardSuite` | The write guards on objects loaded from another app. Confirms `unlock`, `postScore`, `saveData`, `saveDataRaw` and `clearData` all throw on a foreign object — and that the reads (`loadDataRaw`, `getScores`) and every local object are left alone |

### Live — real gateway (89 tests, 91 with the sign-out suite)

| Suite | Needs login? | Notes |
|---|---|---|
| `LiveGateSuite` | no | The confirmation prompt |
| `LiveGatewaySuite` | no | ping, version, server time, host license, custom event. **Read this first when a live run goes wrong** — if ping fails, nothing below matters |
| `LiveSignOutSuite` | — | **Only present when a remembered login exists.** Asks whether to sign out; if you do, ends your real login, checks the stored id is gone, and proves the server rejects the ended session. Keeping it is the default |
| `LiveNoSessionSuite` | no | No session at all. Proves the sixteen components that never touch a session work that way — a medal list on a title screen — and that the session-gated ones are refused with `[102] Missing required session_id` |
| `LiveSessionSuite` | — | Proves a session can be obtained at all, before anything depends on one |
| `LiveGuestSuite` | no | A real session id with no user attached. Reads stay open; writes and per-user queries are refused with `[110] User is not logged in` — a *different* code from the no-session case, which is why these are two suites. Also the only coverage `App.endSession` gets |
| `LiveSignInSuite` | — | The Passport flow: attaches a user, or confirms one already is. Also checks the session id reaches local storage when — and only when — the server sets `remember` |
| `LiveAppDataSuite` | partly | Batch-loads medals/scoreboards/save slots, checks counts against `TestConfig`, verifies lookup-by-id returns cached instances |
| `LiveMedalSuite` | yes | The encrypted `Medal.unlock` path, repeat unlocks, unknown-id rejection |
| `LiveScoreBoardSuite` | yes | `postScore` (also encrypted), plus every documented `getScores` filter — including `social` on a **local** board, which was previously only exercised cross-app. Also probes the server's own `limit` clamping and `skip` handling through `callComponent`, since the model throws before those can reach the gateway |
| `LiveCloudSaveSuite` | yes | Write, read back over HTTP, structured round-trip, clear |
| `LiveCrossAppSuite` | partly | Reads another app's data via the `app_id` parameter, proves it cannot reach this app's caches, and checks that a foreign board forwards its `app_id` (and accepts a `social` filter) on reads while a foreign medal refuses to unlock |
| `LiveLoaderSuite` | no | Resolves all five Loader URLs using the non-redirect form, so it doesn't open browser tabs |

Tests needing a user report `[SKIP]` rather than `[FAIL]` when you run as a
guest, so a guest-only run still reads cleanly.

#### Each session suite makes the state it tests

A single run covers all three session states on any machine, whatever you happen
to be logged into, with no prompt and no state-dependent skips. Neither suite
waits for a run that happens to be in the right state — each creates it:

| Suite | How it gets there | Cost |
|---|---|---|
| `LiveNoSessionSuite` | `setUp` **parks** the session `AppState` restored, `tearDown` puts it back | Nothing sent; no session ended |
| `LiveGuestSuite` | Parks any login, then asks the gateway for a **real guest session**; ends it; restores the parked login | 3 extra gateway calls |

Parking is purely local and entirely honest: the request envelope is built from
`appState.session.id` ([Core.as:429](../build/io/newgrounds/Core.as#L429)), so
clearing that id reproduces exactly the wire condition being tested — a request
with no `session_id`. Your login is never ended and never leaves the machine.

Guest state cannot be faked that way. *"This session has no user"* is a judgement
the **server** makes, so a locally-faked guest session would still be signed in
as far as the gateway is concerned and every refusal test would fail. Hence the
real guest session.

**This is also why `App.endSession` no longer needs a prompt.** It is tested on
the throwaway guest session the suite just created, so nobody's login is at
stake. One consequence worth knowing: `endSession` clears the stored session id,
so a run leaves nothing remembered on the machine and the next one signs in
fresh.

Previously the no-session suite relied on finding a naturally session-free window
between `init()` and the first `checkSession()`. That window does not exist for
either common case — a developer with a remembered login, or a game embedded on
Newgrounds where the URL supplies `ngio_session_id` — so on exactly the machines
people test on the whole suite reported permanent skips.

#### The one state that cannot be manufactured

**Signing out.** A remembered login requires a human to have signed in through
Passport, so `LiveSignOutSuite` cannot create its own precondition the way the
other two do. Instead it is **registered only when local storage actually holds a
session id** — checked before `NGIO.init()`, since the storage helpers are plain
statics — so a machine with no remembered login simply does not see the suite,
rather than seeing it skip.

When it is present it **asks**, using both on-stage buttons, and keeping your
login is the default (an unanswered prompt lands there). Sign out and you get
three things nothing else covers:

- `App.endSession` against a **real, signed-in, remembered** session rather than
  the throwaway guest one `LiveGuestSuite` creates;
- proof the stored session id is actually removed, so the next launch does not
  auto-login. `LiveGuestSuite` cannot assert this, because it restores your login
  afterwards and the library may re-save the id when the server re-verifies it;
- **proof `endSession` reached the server at all.** It hands its callback nothing
  and clears local state regardless of the reply, so every other assertion about
  it describes the client. The follow-up case puts the dead id back and confirms
  the gateway refuses to honour it.

It runs first, so the rest of the run then exercises the fresh-machine path —
including a genuine Passport sign-in, which you will have to complete.

The other half of that contract is in `LiveSignInSuite`: *saves the session id
locally when the server says remember* checks the id reaches local storage when —
and only when — `session.remember` is true. When `remember` is false it **skips**
rather than asserting the inverse, because `finalizeSessionPersistenceState` only
ever *writes* on true and never clears on false, so an id found in storage during
a `remember=false` run may be a legitimate leftover from an earlier login. The
skip states which answer the server gave.

## Configuration

Everything lives in `ngiotest/TestConfig.as`.

| Setting | Default | Effect |
|---|---|---|
| `RUN_OFFLINE_TESTS` | `true` | |
| `RUN_LIVE_TESTS` | `true` | `false` drops all live suites |
| `LIVE_TEST_PACING_MS` | `750` | Pause between **live** cases. Offline suites are never paced. **Temporary**, at the gateway owner's direction, until the server-side limit is updated — drop back to `100` once that ships. It works because the limit is a count *per time window*: spreading the whole run across more seconds moves requests between windows. Dominates the run at this value — ~69s of pacing in a ~109s run |
| `LOADER_PACING_MS` | `-1` | Pause before each **Loader** case only, overriding the above. `-1` uses the normal pace; kept as the worked example of `TestSuite.pacingMs` |
| `SESSION_THROTTLE_WAIT_MS` | `4000` | How long to wait before a `checkSession` that must genuinely reach the server. `NgioAuthHelper` throttles it to one server call every 3s, and answers locally *without starting a session* inside that window |
| `USE_DEBUG_MODE` | `true` | Gateway validates without committing. Turn off only to verify persistence — then expect to re-lock medals on the server |
| `REQUIRE_LOGIN` | `true` | `false` skips the Passport prompt and everything needing a user |
| `CONFIRM_BEFORE_LIVE` | `true` | `false` goes straight online |
| `APP_ID` / `ENCRYPTION_KEY` | AS3 test app | Unpublished app `61512:1uYiEl7d`, used only for this suite |
| `TEST_SAVE_SLOT_ID` | `1` | Cloud save tests write here and clear it afterwards |

The expected counts (`EXPECTED_MEDAL_COUNT` and friends) are asserted against,
so if the test app's configuration changes on Newgrounds, update them here.

### Rate limiting

The gateway rate limits by request count over a time window. The specific
thresholds are deliberately not documented here — they are operational settings,
and publishing them mostly helps someone work out what they can get away with.

What matters for running these tests: a full run is dense enough to approach the
limit, and has at times been refused on its own final request with an HTTP 429.
That is a property of the suite's size, not a defect — no real game produces
traffic like this. The summary reports a `Requests:` total for any run that
touched the network, so if the suite grows the cost stays visible.

A 429 near the end of a run is therefore expected rather than a regression. If
it happens, wait a short while before re-running rather than retrying
immediately. **If the count grows much further, split the run** rather than
asking for more allowance.

The run now stops itself at the first request that gets no answer, rather than
carrying on. That matters more than it sounds: a rate-limited run does not
simply fail, **it passes tests it should not**. Any test asserting an *absence*
or an *error* goes green when the request never lands — a cache is empty because
nothing loaded, a call "was rejected" because it never arrived. The detection
sits at the network observer (`NetworkLog.transportFailures`) rather than on the
error code, because `INVALID_RESPONSE` covers both "nothing came back" and "a
2xx whose body would not parse", and the second is a real failure that must keep
being reported. Stopping early also protects the *next* window's budget.

**Known hole:** the guard sits in `assertNoError`, so it only covers tests
asserting a call *succeeded*. A test that expects an error and never calls it can
still false-pass if it is the first to meet a dead gateway.

One thing worth knowing, since the failures were misleading while this was being
diagnosed: the limit is not tied to any component. The failure follows whichever
call happens to be last in the run, which for a long time made the `Loader` suite
look guilty when it was simply at the end.

That figure is a **floor**. It counts what the network observer saw, so it
misses any session or preload calls the host made before the runner started,
and it does not count `Loader` urls, which navigate rather than call the
gateway.

**Correction to what this file used to say.** It claimed pacing could not help,
because the limit counts requests rather than measuring a rate. That was the
wrong lesson drawn from a real experiment: slowing the **Loader suite alone**
changed nothing, but only because the fifty-odd requests ahead of it were just as
dense and had already filled the window.

The limit is a count *per time window*, so spreading the **whole run** across
more seconds does move requests between windows. Pacing one suite at the end
cannot; pacing everything can:

| Pacing | Result |
|---|---|
| `100`ms | ~60 requests in ~25s — **refused** on request 60 |
| `750`ms | 73 requests, no refusal (~109s total) — the current setting |
| `1200`ms | 71 requests, no refusal |

If a run is ever refused, `LIVE_TEST_PACING_MS` is the first number to raise.

Two honest limits on it: it paces **cases, not calls**, so a test making three
gateway calls still bursts them; and it does not reduce the request *count*. It
is a way of staying under the limit, not of making the suite cheaper. Leaving a
gap between runs still matters.

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
test by name, and reports a `Requests:` total for any run that touched the
network.

`Duration:` splits human wait-time out of the headline figure:

```
Duration:   99.5s running, plus 13.9s waiting for a human (113.4s total)
```

The first number is what the **suite** costs, and it is the one to judge pacing
and run cost by. Anything that put a prompt on screen — the live-testing gate,
the sign-out choice, Passport sign-in — is charged to the second. A run that sat
on the confirmation button used to report the combined figure, which reads as a
slow suite rather than a distracted tester. Runs with no prompt at all print a
single number.

### What the on-stage text shows

`infoText` names the **suite** in progress and nothing finer:

```
Live / Sign-in   (11 of 20)

Running - results appear in the Output panel.
```

It changes exactly twice per suite: when the suite starts, and when a test needs
an answer from you — after which the banner comes straight back.

This is deliberate. It used to update per test, which sounds more informative
and was not: a test finishes in milliseconds while a person reads at human
speed, so the line on screen was almost always describing work that had already
finished, and a prompt or status message would sit there for the rest of the run.
The Output panel is the report; the stage is a sign saying which part of the run
you are in.

`TestContext.status()` still exists for the one case that earns it — telling you
the suite is polling after you have clicked through to Passport — but it is not a
progress display, and the runner overwrites it when the case ends.

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

> **Check the component name in the header before trusting a packet.** The log
> is a flat, time-ordered buffer that is cleared at the start of each test — it
> does not pair requests with responses. A call still in flight when a test ends
> lands in the *next* test's dump, so a failure can show a packet that has
> nothing to do with it. Each block is labelled `--- RESPONSE (Gateway.getVersion) ---`
> for exactly this reason. Encrypted calls show as `(secure)`, since the
> component name is inside the blob; the decrypted body appears in the packet
> itself.

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
- **A second button is optional.** `inputButton2` / `inputButtonLabel2` drive
  `TestContext.promptChoice()`, used where the harness needs a genuine either/or
  answer — currently the sign-out prompt, which must not guess. A stage without
  the two objects still runs every single-choice prompt, and `promptChoice`
  **skips** rather than fails, because unlike `prompt()` there is no sensible
  default. On such a stage the sign-out path is simply not offered.
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

**Fully green.** Run twice on 2026-08-16 from `NgioUnitTest.fla` in the Flash
IDE, from a machine with a remembered login — once down each branch of the
sign-out prompt, so both paths through the suite are verified rather than one:

| Sign-out prompt | Passed | Failed | Skipped | Assertions | Requests | Duration |
|---|---|---|---|---|---|---|
| **Sign out and test it** | 200 | 0 | 2 | 990 | 78 | 98.0s running + 55.0s human |
| **Keep my login** | 198 | 0 | 4 | 989 | 75 | 98.0s running + 32.4s human |

Both branches have been run more than once and reproduce their counts exactly —
same passes, skips, assertions and request total each time.

**The two branches cost the same 98.0s of suite time**, to the tenth of a second,
while their human wait differed by 23 seconds. That is the duration split doing
precisely what it exists for: before it, these same two runs reported 131.1s and
129.0s and looked like ordinary run-to-run variance. The three extra gateway
calls the sign-out branch makes are lost in the pacing, which is most of the 98s
either way.

Both reconcile to the same 202 cases (112 offline + 90 live; `LiveGateSuite`
registers two mutually exclusive cases and runs one). The whole suite compiles
clean under `-strict=true` against Flash Player 10.2.

**Signing out is the more thorough run**, which is worth knowing before you
answer the prompt. It costs a Passport sign-in and 3 extra gateway calls, and in
exchange the two sign-out cases execute instead of skipping — so it has *fewer*
skips than keeping your login, not more.

| Skipped | On which branch | Why |
|---|---|---|
| `ScoreBoard` clamping probes (2) | both | server-side clamping is not enabled on this gateway |
| `Live / Sign-out` (2) | keep only | you chose to keep your login, so there is no ended session to re-offer |

Every remaining skip is a stated choice or a server-side condition. **No skip is
a masked failure, and none is state-dependent** — down from the 10 skips of the
previous run, all of which were "that state was not available today".

Two things these runs confirmed for the first time:

- **`endSession` reaches the server.** Re-offering the ended id came back
  `not-logged-in`, and the gateway did not hand the dead id back. Until this run,
  every assertion about `endSession` described only the client.
- **The gateway echoes `remember` on a *restored* session**, not just at the
  moment of Passport sign-in. Both runs reported `session.remember = true` — the
  keep-login run on a session restored from local storage and re-verified, the
  sign-out run on a session freshly issued through Passport. Had the echo been
  missing, the library's re-save on every result would quietly stop refreshing a
  remembered login.

The AS2 suite was run identically the same day and matched exactly where it
should: 78 and 75 gateway calls on the two branches, the same two `remember`
observations, the same skip pattern. The libraries carry identical live coverage
(91 registered cases in each), so the passed/skipped totals differ only by the
offline count.

**The two libraries cost the same to run.** AS3 spends **98.0s**, AS2 **100.6s**,
on the same 90 live cases at the same 750ms pacing.

This file previously claimed AS3 was ~30s slower, and that was wrong — it was an
artefact of the very gap that has since been closed. AS3 had no human-wait split,
so its 129s headline silently included the tester reading prompts; AS2's 99.5s
did not. Splitting the figure removed the difference entirely. Worth remembering
as a caution about the numbers in this file: **a measurement that only one of the
two libraries takes is not a comparison.**

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
