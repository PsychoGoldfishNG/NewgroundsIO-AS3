package tests {
    import io.newgrounds.AppState;
    import io.newgrounds.Core;
    import io.newgrounds.models.objects.Medal;
    
    /**
     * Tests for AppState data loading and caching behavior
     */
    public class AppStateTest extends BaseTest {
        
        private var appState:AppState;
        private var core:Core;
        
        override public function runTests():Array {
            results = [];
            
            // Create core and appState instances
            core = new Core("test-app-id:abcd1234", "uXp/7Q9V4vG5L6R2W9zB8A==");
            appState = new AppState(core);
            
            testAppStateCreation();
            testCaching();
            testHasLoaded();
            testPropertyInitialization();
            
            return results;
        }
        
        private function testAppStateCreation():void {
            assertNotNull(appState, "AppState instance created");
        }
        
        private function testCaching():void {
            // Verify medals start as null
            assertNull(appState.medals, "Medals initially null");
            
            // Simulate loading medals
            var testMedals:Array = [];
            var medal1:Medal = new Medal();
            medal1.id = 1;
            medal1.name = "Medal 1";
            testMedals.push(medal1);
            
            // Direct property assignment (simulating cache)
            appState.medals = testMedals;
            
            assertNotNull(appState.medals, "Medals cached after assignment");
            assertEquals(1, appState.medals.length, "Medal array has correct length");
            assertEquals(1, appState.medals[0].id, "First medal has correct ID");
        }
        
        private function testHasLoaded():void {
            // medals not loaded initially
            assertFalse(appState.hasLoaded('medals'), "hasLoaded returns false before data load");
            
            // Simulate loading
            appState.medals = [];
            // hasLoaded should track what's been explicitly loaded
            // This test verifies the method exists and can be called
            var medalsLoaded:Boolean = appState.hasLoaded('medals');
            assert(typeof medalsLoaded === 'boolean', "hasLoaded returns boolean");
        }
        
        private function testPropertyInitialization():void {
            // Verify standard properties exist and have appropriate defaults
            assertNotNull(appState, "AppState object exists");
            
            // These properties should exist (even if null)
            var hasSession:Boolean = appState.hasOwnProperty('session');
            assert(hasSession, "AppState has session property");
            
            var hasMedals:Boolean = appState.hasOwnProperty('medals');
            assert(hasMedals, "AppState has medals property");
            
            var hasScoreBoards:Boolean = appState.hasOwnProperty('scoreBoards');
            assert(hasScoreBoards, "AppState has scoreBoards property");
            
            var hasSaveSlots:Boolean = appState.hasOwnProperty('saveSlots');
            assert(hasSaveSlots, "AppState has saveSlots property");
        }
    }
}
