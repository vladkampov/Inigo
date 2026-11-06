# Browser extension retirement

The experimental Chrome and Safari extensions are deprecated and removed. Inigo no longer starts a browser bridge, listens for extension requests, or writes browser connection tokens.

Use the Inigo shortcut or macOS Services with selected text instead. Only the selection is processed, without surrounding browser context. Some editors require copying the result; universal in-place replacement is not promised.

If you installed a development extension, remove Inigo from your browser’s Extensions settings. Chrome development users can also remove `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/app.inigo.personal.json`. It is no longer used. Safari development users can remove the separate Inigo Browser app. Existing installations cannot connect to the new app.
