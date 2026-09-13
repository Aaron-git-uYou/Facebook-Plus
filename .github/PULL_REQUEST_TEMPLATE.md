<!--
Thanks for contributing to Facebook Plus. Please fill in the sections below and
delete the comment blocks. Keep the PR focused on a single change where possible.
-->

## Summary

<!-- What does this PR do, and why? One or two paragraphs. -->

## Related issue

<!-- Link the issue this closes, e.g. "Closes #12". Use "Refs #12" if it only relates. -->
Closes #

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (adds a toggle or capability)
- [ ] Compatibility fix (adapts to a new Facebook build)
- [ ] Refactor / internal cleanup (no behaviour change)
- [ ] Documentation only
- [ ] Localization (strings / a new `.lproj`)

## Testing

<!-- How was this verified? Be specific — screenshots or a screen recording help. -->

- **Install method:** <!-- jailbroken (.deb) / non-jailbroken, public cert / non-jailbroken, personal cert -->
- **Facebook build:** <!-- e.g. 574.0.0 -->
- **Device / iOS:** <!-- e.g. iPhone 13, iOS 16.5 -->

<!-- Describe the steps you ran and what you observed. -->

## Checklist

- [ ] Builds cleanly with `make package FINALPACKAGE=1`.
- [ ] Tested on a real device with the affected feature toggled on **and** off.
- [ ] Any new hook checks its target class/selector exists before installing, so a future Facebook update degrades only that feature.
- [ ] The tweak's own views stay `FBP`-prefixed (so the OLED sweep leaves their colours alone).
- [ ] User-facing strings are localized via `FBPL(...)` and added to `Localizations/Base.lproj` (and others where possible).
- [ ] Comments are professional and explain *why*, not *what*; no leftover debug logging in the release path.
- [ ] I have not committed build artifacts, the decrypted IPA, or other gitignored files.

## Notes for reviewers

<!-- Anything else worth flagging: trade-offs, follow-ups, areas that need a closer look. -->
