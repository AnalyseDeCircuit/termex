# JetBrains Mono Font Files

Place the following files in this directory before building:

- `JetBrainsMono-Regular.ttf`
- `JetBrainsMono-Bold.ttf`

## Download

```bash
# via Homebrew (macOS)
brew install --cask font-jetbrains-mono

# Manual: https://www.jetbrains.com/lp/mono/
# Download the ZIP, extract, copy the two TTF files here.

# via curl (GitHub release)
curl -L "https://github.com/JetBrains/JetBrainsMono/releases/latest/download/JetBrainsMono-2.304.zip" \
  -o /tmp/jbmono.zip && unzip /tmp/jbmono.zip -d /tmp/jbmono \
  && cp /tmp/jbmono/fonts/ttf/JetBrainsMono-Regular.ttf . \
  && cp /tmp/jbmono/fonts/ttf/JetBrainsMono-Bold.ttf .
```

Without these files, `flutter build` will warn but continue —
the terminal will fall back to Menlo / Consolas / Courier New.
