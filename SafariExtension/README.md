# Safari extension

The native wrapper and Safari-specific `sendNativeMessage` transport compile. It uses a shared App Group route file and authenticated loopback requests. Private-mode access fails closed unless Safari explicitly reports `incognito === false`. The handler never logs or echoes writing.

## Activation requirements

Configure the same Apple developer team and the `group.app.inigo.personal` App Group for Inigo and the Safari extension. Build the main app with `INIGO_SIGN_IDENTITY` set to that team's signing identity; this enables the shared route and signs with `scripts/Inigo.entitlements`. Set the team in the generated Xcode project, build the Safari container, and enable its extension in Safari settings.

There is no signing identity installed on the current Mac, so the personal ad-hoc app does not advertise the App Group route. The Safari wrapper has been built with `CODE_SIGNING_ALLOWED=NO` for compilation verification only, not activated or claimed as working in Safari.

Chrome does not need this App Group transport; use its narrow native-messaging registration script.
