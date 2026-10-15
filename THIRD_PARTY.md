# Third-party components

The root MIT license covers original work where no other notice applies. It
does not relicense imported code. Distributing the combined shell must respect
the GPL obligations of its imported Ryoku components; do not describe the entire
combined application as MIT-only.

- **Ryoku music components**: GPL-3.0, revision
  `98a0368253d9628be72b853985878a5db90e1547`, from
  https://github.com/ryoku-dev/ryoku. Full license and adaptation notice are in
  `.config/quickshell/tartarus-shell/bar/components/ryoku/`. The parent music
  component is also an adaptation, as described in that notice.
- **Capture / Ryoshot**: retain the MIT license and copyright in
  `.config/quickshell/tartarus-shell/capture/LICENSE`.
- **Sung**: https://github.com/yappologistic/Sung, vendored at
  `4918f7610725cace300db557b1f636ec1b80e260`. MIT license retained in `Sung/LICENSE`;
  font/icon notices are preserved under `Sung/licenses/`. This is a source
  snapshot, not a Git submodule or a replacement for its upstream history.
- **Rashin**: independent implementation; its architectural references and
  license boundaries are documented in `tools/tartarus-rashin/NOTICE`.

Hermes, llama.cpp and model weights are external dependencies, not bundled
here. Their upstream licenses and model terms continue to apply.
