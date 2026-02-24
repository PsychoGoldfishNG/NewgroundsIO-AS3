# NewgroundsIO-AS3 Test Suite

## Installation Complete! ✓

Apache Flex SDK 4.16.1 has been installed to: `C:\flex-sdk`

## Test Suite Structure

```
test/
├── TestRunner.as              - Main test runner (displays results)
├── build-tests.ps1            - PowerShell build script
└── tests/
    ├── ITestSuite.as          - Test suite interface
    ├── TestResult.as          - Test result class
    ├── BaseTest.as            - Base class with assertions
    ├── BaseObjectTest.as      - Tests for BaseObject serialization
    ├── CoreTest.as            - Tests for Core (encryption, etc.)
    ├── MedalTest.as           - Tests for Medal class
    └── ObjectFactoryTest.as   - Tests for ObjectFactory
```

## Running Tests

### Option 1: Using the Build Script

```powershell
cd test
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\build-tests.ps1
```

This will compile `TestRunner.swf` which you can open in Flash Player.

### Option 2: Manual Compilation

```powershell
cd test
& "C:\flex-sdk\bin\mxmlc.bat" -source-path+="..\build" -source-path+="." -output "TestRunner.swf" TestRunner.as
```

### Option 3: Flash/FlashDevelop IDE

1. Open the project in FlashDevelop or Flash Professional
2. Add `test/` directory to your classpath
3. Set `TestRunner.as` as the document class
4. Build and run

## Test Coverage

The test suite currently covers:

### BaseObjectTest
- **Deserialization**: Converting JSON to AS3 objects (Medal, User)
- **Serialization**: Converting AS3 objects to JSON
- **Property validation**: Checking propertyNames, requiredProperties
- **Type casting**: Verifying castTypes map works correctly

### CoreTest
- **Encryption**: AES-128-CBC encryption with as3crypto
- **App ID parsing**: Extracting app ID and session ID
- **Session management**: hasSession() and session state

### MedalTest
- **Medal creation**: Object instantiation
- **Medal properties**: Setting and getting all properties
- **Session clearing**: clearSessionData() behavior

### ObjectFactoryTest
- **CreateObject()**: Dynamic object instantiation
- **CreateComponent()**: Component creation by name
- **CreateResult()**: Result creation by name
- **Case insensitivity**: "medal", "MEDAL", "Medal" all work
- **Invalid names**: Returns null for unknown types

## Assertion Methods

The `BaseTest` class provides these assertions:

- `assert(condition, testName, message)` - Generic assertion
- `assertEquals(expected, actual, testName)` - Value equality
- `assertNotNull(value, testName)` - Non-null check
- `assertNull(value, testName)` - Null check
- `assertTrue(value, testName)` - Boolean true
- `assertFalse(value, testName)` - Boolean false

## Adding New Tests

1. Create a new test class extending `BaseTest`:

```actionscript
package tests {
    public class MyNewTest extends BaseTest {
        override public function runTests():Array {
            results = [];
            
            testSomething();
            testSomethingElse();
            
            return results;
        }
        
        private function testSomething():void {
            var result:int = 1 + 1;
            assertEquals(2, result, "Math works");
        }
    }
}
```

2. Register it in `TestRunner.as`:

```actionscript
runTestSuite("My New Tests", new MyNewTest());
```

## Flash Player

To run the compiled SWF, you'll need Flash Player:
- **Standalone**: https://www.adobe.com/support/flashplayer/debug_downloads.html
- **Browser plugin**: (if browser supports Flash)

## Next Steps

- Add more test cases for SaveSlot, ScoreBoard, Session
- Add integration tests with mock API responses
- Add performance tests for encryption/serialization
- Set up automated CI/CD testing

## Troubleshooting

### "playerglobal.swc not found"
Already fixed! Downloaded to `C:\flex-sdk\frameworks\libs/player/11.1/`

### "mxmlc not recognized"
Add to PATH or use full path: `C:\flex-sdk\bin\mxmlc.bat`

### Compilation errors
Check that all source paths are correct:
- `../build` - Contains the library classes
- `.` - Contains the test classes

