# Moonfall explainer video

Remotion project for the pre-game briefing video (1920x1080, 30 fps, English, about 2:46).

```bash
cd video && npm install
npm run audio    # generate the music bed and sound effects into public/audio
npm run script   # regenerate script.md and out/explainer.en.srt from src/script.ts
npm run studio   # preview
npm run render   # out/explainer.mp4
```

- `src/script.ts` is the single source for narration lines and timings. Every scene reads its line start frames from it.
- To add the voice-over: put the recording in `public/audio/`, set `VOICEOVER_FILE` in `src/config.ts`, then adjust line durations in `src/script.ts` to match the recording and rerun `npm run script`. The music bed ducks automatically.
- Numbers shown come from `Shared/Game/GameTypes.swift`: kill cooldown 60 s, sabotage cooldown 120 s, sabotage countdown 90 s, 45 minute game, 2 + 2 minute meetings.
