# as3crypto Library

This directory contains the as3crypto library by Henri Torgemane, used for AES-128-CBC encryption in the NewgroundsIO-AS3 library.

## Source

- **Repository:** https://github.com/timkurvers/as3-crypto
- **License:** BSD License (see LICENSE.txt in library)
- **Purpose:** Provides cryptographic functions for encrypting secure API components

## Usage in NewgroundsIO-AS3

The library is used in `Core.encryptData()` to encrypt secure components (medal unlocks, score posts) before transmission to the Newgrounds.io API.

**Encryption Configuration:**
- Algorithm: AES-128-CBC
- Padding: PKCS5
- Output: Base64-encoded ciphertext
- Mode: `simple-aes-cbc` (automatically prepends IV to ciphertext)

**Key Classes:**
- `com.hurlant.crypto.Crypto` - Factory for creating ciphers
- `com.hurlant.crypto.symmetric.AESKey` - AES implementation
- `com.hurlant.crypto.symmetric.PKCS5` - PKCS5 padding
- `com.hurlant.util.Base64` - Base64 encoding/decoding
- `com.hurlant.util.Hex` - Hex string utilities

## Integration

The library is integrated directly into the build directory to simplify compilation for Flash developers. No external SWC or linking is required - simply include the source files in your Flash project.

## Example

```actionscript
import com.hurlant.crypto.Crypto;
import com.hurlant.crypto.symmetric.ICipher;
import com.hurlant.crypto.symmetric.PKCS5;
import com.hurlant.util.Base64;
import com.hurlant.util.Hex;
import flash.utils.ByteArray;

// Convert hex key to ByteArray
var keyBytes:ByteArray = Hex.toArray(encryptionKeyHex);

// Create AES-128-CBC cipher with PKCS5 padding
var cipher:ICipher = Crypto.getCipher("simple-aes-cbc", keyBytes, new PKCS5());

// Encrypt data
var inputBytes:ByteArray = new ByteArray();
inputBytes.writeUTFBytes(textToEncrypt);
cipher.encrypt(inputBytes);
inputBytes.position = 0;

// Encode as Base64
var encryptedBase64:String = Base64.encodeByteArray(inputBytes);
```
