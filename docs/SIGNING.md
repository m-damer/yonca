# Release signing key

Every YONCA update must be signed with the same key. If the key or its password is lost, phones refuse to update the app and you must reinstall. The password is the one thing you must never lose.

## How it is protected

The key file lives in this public repo as `release/yonca-release.jks`, but it is locked with a password that only you and GitHub's secret store know. Anyone can download the file; without a strong password it is useless. So the password must be long and random.

## Steps (once)

1. Make a password of 24 or more random characters with your password manager's generator (letters and digits only, no spaces). Save it in the password manager and also write it somewhere offline.
2. In the repo open **Settings, Secrets and variables, Actions, New repository secret**. Name: `YONCA_KEY_PASSWORD`. Value: the password.
3. Open **Actions, Generate release signing key, Run workflow**. It refuses to run if the password is shorter than 20 characters, and it never replaces an existing key.
4. Open **Actions, Build signed APK, Run workflow**. The log shows a SHA256 fingerprint; note it down. It must be the same on every future release.
5. Copy `release/yonca-release.jks` from the repo to a second safe place as a backup.

Claude never sees the password.
