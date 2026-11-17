# Deep Link Verification Files

Host this folder at:

- https://snapstake.app/.well-known/
- https://www.snapstake.app/.well-known/

Required for Android App Links:

- `assetlinks.json`

## Replace the fingerprint placeholder

`assetlinks.json` currently contains a placeholder fingerprint.

Get your SHA-256 release/upload certificate fingerprint and replace:

```bash
keytool -list -v -keystore /path/to/upload-keystore.jks -alias upload
```

Then copy the `SHA256:` value into `sha256_cert_fingerprints`.

## Verify after deploy

You can test verification on a device with:

```bash
adb shell pm get-app-links com.snapstake.app
```

And test opening links:

```bash
adb shell am start -a android.intent.action.VIEW -d "https://snapstake.app/m/test"
```
