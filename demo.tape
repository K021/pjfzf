Output assets/demo.gif

Set Shell "zsh"
Set FontSize 16
Set Width 1000
Set Height 600
Set Padding 20
Set Theme "Dracula"
Set TypingSpeed 60ms

# Source pj
Hide
Type "source ./pj.zsh"
Enter
Sleep 500ms
Type "mkdir -p /tmp/pj-demo/projects/web-app /tmp/pj-demo/projects/api-server /tmp/pj-demo/projects/cli-tool /tmp/pj-demo/work/data-pipeline /tmp/pj-demo/work/ml-model"
Enter
Sleep 300ms
# Reset config for clean demo
Type "rm -rf ~/.config/pj && _PJ_CONFIG_DIR=~/.config/pj && _PJ_CONFIG_FILE=$_PJ_CONFIG_DIR/config && _PJ_HISTORY_FILE=$_PJ_CONFIG_DIR/history"
Enter
Sleep 300ms
Type "_pj_init"
Enter
Sleep 300ms
Show

# Scene 1: Add base directories
Sleep 500ms
Type "# Register project directories"
Enter
Sleep 800ms
Type "pj add /tmp/pj-demo/projects"
Enter
Sleep 1s
Type "pj add /tmp/pj-demo/work"
Enter
Sleep 1s

# Scene 2: Navigate with pj
Sleep 500ms
Type "# Navigate to a project with fuzzy finding"
Enter
Sleep 800ms
Type "pj api"
Sleep 2s
Enter
Sleep 1s
Type "pwd"
Enter
Sleep 1.5s

# Scene 3: Create a new project
Type "# Create a new project directory"
Enter
Sleep 800ms
Type "pjmk my-new-app"
Sleep 1.5s
# Select first base dir
Enter
Sleep 1s
Type "pwd"
Enter
Sleep 1.5s

# Scene 4: Show list
Type "pj list"
Enter
Sleep 2s

Sleep 1s
