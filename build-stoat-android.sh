#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

REPO_DIR="stoat-for-android"
REMOTE_DEFAULT="ssh://git@git.taile3c5e.ts.net/snockow6/stoat-for-android.git"

echo "=== Stoat Android Build ==="

# --- Parse args ---
SERVER=""
REMOTE="$REMOTE_DEFAULT"
BRANCH="dev"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--server) SERVER="$2"; shift 2 ;;
        -r|--remote) REMOTE="$2"; shift 2 ;;
        -b|--branch) BRANCH="$2"; shift 2 ;;
        *) echo "Usage: $0 [--server URL] [--remote URL] [--branch BRANCH]"; exit 1 ;;
    esac
done

# --- Clone or pull stoat-for-android into subdirectory ---
if [ -d "$REPO_DIR/.git" ]; then
    echo "Updating $REPO_DIR..."
    cd "$REPO_DIR"
    git fetch origin
    git checkout "$BRANCH" 2>/dev/null || true
    git pull origin "$BRANCH" 2>/dev/null || true
    cd "$DIR"
else
    echo "Cloning $REMOTE into $REPO_DIR..."
    git clone --branch "$BRANCH" "$REMOTE" "$REPO_DIR"
fi

cd "$REPO_DIR"

# --- Apply voice patches ---
echo ""
echo "--- Applying voice patches ---"

VOICE_SHEET="app/src/main/java/chat/stoat/composables/voice/VoiceSheet.kt"
BUILD_GRADLE="app/build.gradle.kts"
EXPERIMENTS="app/src/main/java/chat/stoat/screens/settings/ExperimentsSettingsScreen.kt"
MAIN_ACTIVITY="app/src/main/java/chat/stoat/activities/MainActivity.kt"

if [ -f "$VOICE_SHEET" ] && grep -q '^/\*' "$VOICE_SHEET" 2>/dev/null; then
    echo "Patching VoiceSheet.kt..."
    python3 <<'PYEOF'
import re
with open('app/src/main/java/chat/stoat/composables/voice/VoiceSheet.kt', 'r') as f:
    text = f.read()

stub_pattern = re.compile(
    r'class VoiceSheetViewModel\(private val state: SavedStateHandle\) : ViewModel\(\) \{\}\n\n@Composable\nfun VoiceSheet\([\s\S]*?\) \{\s*?\}',
    re.DOTALL
)
text = stub_pattern.sub('', text)
text = text.replace('/*', '').replace('*/', '')

with open('app/src/main/java/chat/stoat/composables/voice/VoiceSheet.kt', 'w') as f:
    f.write(text)
PYEOF
    echo "  patched VoiceSheet.kt"
else
    echo "  VoiceSheet.kt already patched (skipped)"
fi

if [ -f "$BUILD_GRADLE" ] && grep -q '/\*implementation\|implementation.*\*/' "$BUILD_GRADLE" 2>/dev/null; then
    echo "Patching build.gradle.kts..."
    python3 <<'PYEOF'
with open('app/build.gradle.kts', 'r') as f:
    text = f.read()

text = text.replace('/*implementation(libs.livekit.android)', 'implementation(libs.livekit.android)')
text = text.replace('implementation(libs.livekit.android.compose)*/', 'implementation(libs.livekit.android.compose)')
text = text.replace('*/', '')

if 'ndkVersion' not in text:
    text = text.replace(
        'compileSdk = libs.versions.compileSdk.get().toInt()',
        'compileSdk = libs.versions.compileSdk.get().toInt()\n    ndkVersion = project.findProperty("android.ndkVersion") as? String ?: "27.0.12077973"'
    )

with open('app/build.gradle.kts', 'w') as f:
    f.write(text)
PYEOF
    echo "  patched build.gradle.kts"
else
    echo "  build.gradle.kts already patched (skipped)"
fi

if [ -f "$EXPERIMENTS" ] && grep -q 'onCheckedChange = null' "$EXPERIMENTS" 2>/dev/null; then
    echo "Patching ExperimentsSettingsScreen.kt..."
    python3 <<'PYEOF'
with open('app/src/main/java/chat/stoat/screens/settings/ExperimentsSettingsScreen.kt', 'r') as f:
    text = f.read()

text = text.replace(
    'onCheckedChange = null',
    'onCheckedChange = { viewModel.setUseVoiceChats2p0(it) }'
)
text = text.replace(
    '‼️ **Not available in this build!** ‼️',
    '⚠️ **Experimental!** ⚠️'
)

with open('app/src/main/java/chat/stoat/screens/settings/ExperimentsSettingsScreen.kt', 'w') as f:
    f.write(text)
PYEOF
    echo "  patched ExperimentsSettingsScreen.kt"
else
    echo "  ExperimentsSettingsScreen.kt already patched (skipped)"
fi

if [ -f "$MAIN_ACTIVITY" ] && grep -q 'animateFloatAsState\|chatUIScale' "$MAIN_ACTIVITY" 2>/dev/null; then
    echo "Patching MainActivity.kt..."
    python3 <<'PYEOF'
import re
with open('app/src/main/java/chat/stoat/activities/MainActivity.kt', 'r') as f:
    text = f.read()

text = re.sub(r'\n    val chatUIScale by animateFloatAsState\(.*?EasingTokens\.EmphasizedDecelerate\n    \)', '', text, flags=re.DOTALL)
text = re.sub(r'\n    val chatUIOpacity by animateFloatAsState\(.*?EasingTokens\.EmphasizedDecelerate\n    \)', '', text, flags=re.DOTALL)
text = re.sub(
    r'\n    val keyboardController = LocalSoftwareKeyboardController\.current'
    r'\n    LaunchedEffect\(showVoiceUI\) \{'
    r'\n        if \(showVoiceUI\) keyboardController\?\.hide\(\)'
    r'\n    \}',
    '',
    text
)
text = re.sub(
    r'\n            if \(showVoiceUI\) \{ .*? clickable\(.*?showVoiceUI = false.*?\}.*?\}.*?\}',
    '',
    text,
    flags=re.DOTALL
)
text = text.replace(
    '                    .fillMaxSize()\n                    .scale(chatUIScale)\n                    .alpha(chatUIOpacity),',
    '                    .fillMaxSize(),'
)
for imp in [
    'import androidx.compose.animation.core.animateFloatAsState\n',
    'import androidx.compose.ui.draw.alpha\n',
    'import androidx.compose.ui.draw.scale\n',
    'import androidx.compose.ui.platform.LocalSoftwareKeyboardController\n',
]:
    text = text.replace(imp, '')

with open('app/src/main/java/chat/stoat/activities/MainActivity.kt', 'w') as f:
    f.write(text)
PYEOF
    echo "  patched MainActivity.kt"
else
    echo "  MainActivity.kt already patched (skipped)"
fi

echo ""
echo "=== Patches applied successfully ==="

# --- Build ---
echo ""
echo "--- Building ---"
exec bash build.sh ${SERVER:+--server "$SERVER"}
