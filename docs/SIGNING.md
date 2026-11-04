# Release signing key

Every YONCA update must be signed with the same key. If the key or its passwords are lost, phones refuse to update the app and you must reinstall. **Never lose the key file and its passwords, and never commit them.** They live only on your computer and in GitHub's secret store. Same method as Pillbox.

## One-time setup

1. **Make the key** on your computer (keep the file somewhere safe, with a copy offline):
   `keytool -genkeypair -v -keystore yonca-release.jks -alias yonca -keyalg RSA -keysize 4096 -validity 10000`
   Choose a long random password (the same one for the store and the key is fine). Save it in your password manager.
2. **Turn the key file into text (base64):**
   - Mac: `base64 -i yonca-release.jks | pbcopy`
   - Linux: `base64 -w0 yonca-release.jks`
   - Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("yonca-release.jks")) | Set-Clipboard`
3. **Add four secrets** in the repo: Settings, Secrets and variables, Actions, New repository secret.
   - `YONCA_KEYSTORE_BASE64`: the text from step 2
   - `YONCA_STORE_PASSWORD`: the store password
   - `YONCA_KEY_ALIAS`: `yonca`
   - `YONCA_KEY_PASSWORD`: the key password

## Publish a release

Actions, **Build signed APK**, Run workflow. Type the version (for example `0.1.0`, higher than the last one) and an optional "What's new" note.
It builds, signs and publishes the release with `yonca.apk`. The log shows the SHA256 fingerprint of the key; it must be the same on every release.
The permanent download link is `https://github.com/m-damer/yonca/releases/latest/download/yonca.apk`.

## Google Drive backup

The Drive backup uses Google sign-in, which checks the app's key. For the signed app, in Google Cloud add an Android OAuth client (package `com.yonca.app`) with the release key's SHA-1:
`keytool -list -v -keystore yonca-release.jks -alias yonca`

## Test builds

Test builds from CI are signed with a fixed public debug key (`android/app/debug.keystore`), so each one installs over the last. They cannot update a release build, because the keys differ.
