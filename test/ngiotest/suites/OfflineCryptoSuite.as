/**
 * OfflineCryptoSuite
 *
 * Verifies that Core produces ciphertext the gateway can actually read.
 *
 * Rather than assert weak properties ("output is non-empty, output differs
 * from input"), these tests decrypt Core's output independently using the same
 * as3crypto primitives the server expects: AES-128-CBC, PKCS5 padding, random
 * IV prepended to the ciphertext, the whole thing Base64 encoded. If any of
 * those details drift, the round-trip breaks here instead of turning into an
 * "encrypted object failed to decrypt" (error 201) against a live app.
 */
package ngiotest.suites {

    import com.hurlant.crypto.Crypto;
    import com.hurlant.crypto.symmetric.ICipher;
    import com.hurlant.crypto.symmetric.PKCS5;
    import com.hurlant.util.Base64;

    import flash.utils.ByteArray;

    import io.newgrounds.Core;
    import io.newgrounds.NGJSON;

    import ngiotest.TestConfig;
    import ngiotest.TestContext;
    import ngiotest.TestSuite;

    public class OfflineCryptoSuite extends TestSuite {

        /** AES block size in bytes - the IV occupies exactly one block */
        private static const BLOCK_SIZE:int = 16;

        private var core:Core;

        override public function get suiteName():String {
            return "Offline / Encryption";
        }

        override public function setUp(done:Function):void {
            // Uses the real test-app key so the ciphertext format matches what
            // the live suite will send, but makes no network calls.
            core = new Core("unit-test:crypto", TestConfig.ENCRYPTION_KEY);
            done.call(null);
        }

        override public function build():void {

            add("encryptData() output decrypts back to the original text", function(t:TestContext):void {
                var plain:String = "Hello, Newgrounds!";
                var encrypted:String = core.encryptData(plain);

                if (!t.assertNotNull(encrypted, "encryptData returned a value")) {
                    t.done();
                    return;
                }

                t.assertNotEquals(plain, encrypted, "output is not the plaintext");
                t.assertEquals(plain, decrypt(encrypted), "round-trips through AES-128-CBC");
                t.done();
            });

            add("encryptObject() round-trips a full component payload", function(t:TestContext):void {
                var payload:Object = {
                    component: "Medal.unlock",
                    parameters: { id: 12345 }
                };

                var encrypted:String = core.encryptObject(payload);
                if (!t.assertNotNull(encrypted, "encryptObject returned a value")) {
                    t.done();
                    return;
                }

                var decoded:Object = NGJSON.parse(decrypt(encrypted));
                t.assertNotNull(decoded, "decrypted text parsed as JSON");
                t.assertEquals("Medal.unlock", decoded.component, "component name survived");
                t.assertEquals(12345, decoded.parameters.id, "nested parameter survived");
                t.done();
            });

            add("uses a fresh IV for every call", function(t:TestContext):void {
                // A fixed IV would make identical payloads produce identical
                // ciphertext, which is exactly the pattern a replay attack needs.
                var plain:String = "same input every time";
                var first:String = core.encryptData(plain);
                var second:String = core.encryptData(plain);

                t.assertNotEquals(first, second, "two encryptions of the same text differ");
                t.assertEquals(plain, decrypt(first), "first still decrypts");
                t.assertEquals(plain, decrypt(second), "second still decrypts");
                t.done();
            });

            add("output is Base64 of IV + whole cipher blocks", function(t:TestContext):void {
                var encrypted:String = core.encryptData("block alignment check");
                var raw:ByteArray = Base64.decodeToByteArray(encrypted);

                t.assertTrue(raw.length > BLOCK_SIZE, "output is longer than the IV alone");
                t.assertEquals(0, raw.length % BLOCK_SIZE,
                    "total length is a whole number of 16-byte blocks");
                t.done();
            });

            add("pads correctly at an exact block boundary", function(t:TestContext):void {
                // PKCS5 must append a full block of padding when the plaintext is
                // already block-aligned. Getting this wrong truncates the last
                // character only for inputs that happen to be a multiple of 16.
                var exactlyOneBlock:String = "0123456789ABCDEF";
                t.assertEquals(BLOCK_SIZE, exactlyOneBlock.length, "test input really is one block");

                var encrypted:String = core.encryptData(exactlyOneBlock);
                t.assertEquals(exactlyOneBlock, decrypt(encrypted), "block-aligned input round-trips");

                var raw:ByteArray = Base64.decodeToByteArray(encrypted);
                t.assertEquals(BLOCK_SIZE * 3, raw.length, "IV + data block + full padding block");
                t.done();
            });

            add("handles multi-byte UTF-8 text", function(t:TestContext):void {
                // Encryption works on bytes but the input arrives as a String, so
                // a length-vs-bytes mix-up would corrupt any non-ASCII payload -
                // user names and score tags very much included.
                var unicode:String = "café — 日本語";
                var encrypted:String = core.encryptData(unicode);
                t.assertEquals(unicode, decrypt(encrypted), "non-ASCII text round-trips");
                t.done();
            });

            add("handles an empty string", function(t:TestContext):void {
                var encrypted:String = core.encryptData("");
                if (t.assertNotNull(encrypted, "empty input still produces output")) {
                    t.assertEquals("", decrypt(encrypted), "decrypts back to empty");
                }
                t.done();
            });

            add("returns null when no key was supplied", function(t:TestContext):void {
                // A missing key must fail loudly-ish rather than send plaintext
                // where ciphertext is expected.
                var keyless:Core = new Core("unit-test:nokey", "");
                t.assertNull(keyless.encryptData("secret"), "encryptData with an empty key");
                t.assertNull(keyless.encryptObject({ a: 1 }), "encryptObject with an empty key");

                var nullKey:Core = new Core("unit-test:nullkey", null);
                t.assertNull(nullKey.encryptData("secret"), "encryptData with a null key");
                t.done();
            });

            add("does not consume the stored key between calls", function(t:TestContext):void {
                // The key is held as a ByteArray. Passing it straight to the cipher
                // would leave its position at the end, so the second call would
                // read zero bytes and silently encrypt with an empty key.
                var first:String = core.encryptData("first call");
                var second:String = core.encryptData("second call");
                var third:String = core.encryptData("third call");

                t.assertEquals("first call", decrypt(first), "call 1 decrypts");
                t.assertEquals("second call", decrypt(second), "call 2 decrypts");
                t.assertEquals("third call", decrypt(third), "call 3 decrypts");
                t.done();
            });
        }

        //==================== HELPERS ====================

        /**
         * Independently decrypt what Core produced, using the same key and the
         * cipher configuration the gateway uses.
         */
        private function decrypt(base64Text:String):String {
            var keyBytes:ByteArray = Base64.decodeToByteArray(TestConfig.ENCRYPTION_KEY);
            var cipher:ICipher = Crypto.getCipher("simple-aes-cbc", keyBytes, new PKCS5());

            var data:ByteArray = Base64.decodeToByteArray(base64Text);
            cipher.decrypt(data);

            data.position = 0;
            return data.readUTFBytes(data.length);
        }
    }
}
