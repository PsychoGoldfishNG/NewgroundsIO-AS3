package tests {
    import io.newgrounds.Core;
    import com.hurlant.util.Base64;
    import flash.utils.ByteArray;
    
    /**
     * Tests for Core functionality (encryption, etc.)
     */
    public class CoreTest extends BaseTest {
        
        private var core:Core;
        
        override public function runTests():Array {
            results = [];
            
            // Create core instance with test key
            core = new Core("test-app-id:abcd1234", "uXp/7Q9V4vG5L6R2W9zB8A==");
            
            testEncryption();
            testAppIdParsing();
            testSessionManagement();
            
            return results;
        }
        
        private function testEncryption():void {
            var testString:String = "Hello, World!";
            var encrypted:String = core.encryptData(testString);
            
            assertNotNull(encrypted, "Encryption produces output");
            assert(encrypted.length > 0, "Encrypted string is not empty");
            assert(encrypted != testString, "Encrypted string differs from input");
            
            // Check it's valid base64
            try {
                var decoded:ByteArray = Base64.decodeToByteArray(encrypted);
                assert(decoded.length > 0, "Encrypted data is valid base64");
            } catch (e:Error) {
                assert(false, "Encryption produces valid base64", e.message);
            }
        }
        
        private function testAppIdParsing():void {
            assertEquals("test-app-id:abcd1234", core.appId, "App ID format preserved correctly");
        }
        
        private function testSessionManagement():void {
            // Initially no session
            assertFalse(core.hasSession(), "Initially has no session");
            
            // After setting session ID
            core.sessionId = "test-session-123";
            assertTrue(core.hasSession(), "Has session after setting session ID");
        }
    }
}
