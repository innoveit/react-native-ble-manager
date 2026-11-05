# Contributing

Bug fixes, documentation improvements and small features are welcome. For larger changes, open an issue first to discuss the approach.

## Reporting bugs

Search existing issues first, then use the bug report template. Include a minimal reproduction, library and React Native versions, device model and OS version. BLE behavior can depend on both the phone and the peripheral, so include peripheral details when relevant.

## Local development

Fork and clone the repository, create a branch, then run from the repository root:

```sh
npm install
npm run build
```

Use the [example app](example/README.md) to try your changes. Rebuild the native app after changing Android or iOS code. See [Library development](README.md#library-development) for more details.

## Before opening a pull request

- Keep the change focused and follow the surrounding code style.
- For code changes, run `npm run type:check` and `npm run build` from the root.
- Test affected BLE behavior on a real device. State the platform, device, OS version and peripheral used, and mention anything you could not test.
- For bug fixes, include reproduction steps and a regression test when practical.
- Update `docs/` and TypeScript types if public behavior or APIs change. Clearly describe breaking changes and migration steps.
- Use a descriptive PR title, such as `fix(android): merge manufacturer data` or `docs: clarify scan options`.

Fill in the pull request template so reviewers can understand the change and how you checked it.
