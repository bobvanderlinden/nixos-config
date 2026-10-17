# Phonon transcription

`services.phonon.enable` runs the upstream Phonon-2 CPU container as a Home Manager user service. The host needs Docker enabled, and the user needs access to Docker. The laptop profile already provides this.

The server is available only on `127.0.0.1`, port 8010 by default. Docker downloads the image on first start, and Phonon downloads the model into a persistent Docker volume. First startup therefore needs network access and may take a few minutes. Subsequent starts reuse both downloads.

Inspect the service with `journalctl --user --unit phonon --follow`. Check readiness with `curl --fail http://127.0.0.1:8010/health` before dictating for the first time.

## Switch back to Whisper

In `home/profiles/voice-transcription.nix`, change:

```nix
services.phonon.enable = false;
```

Then apply Home Manager:

```sh
nix run --impure .#switch-home -- --plain
```

This stops Phonon and restores the existing local Whisper large-v3-turbo configuration with Dutch and English language detection. Voxtype's hotkeys, overlay, text replacements, and LLM cleanup are shared by both backends. The Phonon model cache remains available if you enable it again.

## Languages

Phonon-2 documents English support:

- The [model card metadata](https://huggingface.co/FermionResearch/Phonon-2/blob/main/README.md) lists `language: en`.
- The [CPU documentation](https://github.com/fermionresearch/phonon/blob/main/docs/cpu.md) states: "Input envelope: English, 16 kHz audio (mono or stereo)."
- The [HTTP API documentation](https://github.com/fermionresearch/phonon/blob/main/docs/server.md) says the `language` parameter is accepted but not implemented.

Do not assume Dutch support from the multilingual Parakeet base model. Use the Whisper backend for Dutch.
