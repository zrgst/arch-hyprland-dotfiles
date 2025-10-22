# dotfiles
My repo for managing configs via symlinks. One repo. One manifest. One script.

## How it works
- Files live in '~/dotfiles/' mirroring *destinations* with a few remaps.
- '.manifest' lists the repo-relative paths to be linked.
- 'linker.sh' reads '.manifest', creates backups of real files, then symlinks the targets to the repo.

### Layout

```bash
dotfiles/
├─ link.sh
├─ .manifest
├─ config/...          -> maps to ~/.config/...
├─ local/bin/...       -> maps to ~/.local/bin/...
├─ usr/local/bin/...   -> maps to /usr/local/bin/...
└─ home/.zshrc         -> maps to ~/.zshrc
```

## Mapping rules

- 'config/*' → '~/.config/*'

- 'local/*' → '~/.local/*'

- 'usr/local/*' → '/usr/local/*' (uses sudo)

- 'home/*' → '~/*' (e.g. home/.zshrc → ~/.zshrc)

- Fallback (rare): 'name' → '~/.name'

## Requirements
- Bash, GNU coreutils, 'sudo' for '/usr/local/*'
- Git for versioning
- Optional: 'gh' for GitHub

## First time setup

```bash
cd ~/dotfiles
git init
git add .manifest link.sh
# make scripts executable
find local/bin usr/local/bin -type f -print0 2>/dev/null | xargs -0 chmod +x
git add -A
git commit -m "init"
# push (SSH)
git branch -M main
git remote add origin git@github.com:<USER>/<REPO>.git
git push -u origin main
```

# Link files on this machine

Preview:
```bash
cd ~/dotfiles
bash ./link.sh
```

Apply:
```bash
APPLY=1 bash ./link.sh
```
- Non-symlink originals are backed up as '*.bak.YYYYMMDDHHMMSS'.
- '/usr/local/*' will prompt for sudo.

# Add a new file

1. Put it in the repo at the mapped path:

- '~/.config/foo/bar.conf' → 'config/foo/bar.conf'

- '~/.local/bin/mytool' → 'local/bin/mytool'

- '/usr/local/bin/xyz' → 'usr/local/bin/xyz'

- '~/.zshrc' → 'home/.zshrc'

2. Add to .manifest:
```bash
echo 'config/foo/bar.conf' >> .manifest
```

3. If it's a script
```bash
chmod +x local/bin/mytool || true
```

4. Commit, push, and link:
```bash
git add .manifest config/foo/bar.conf local/bin/mytool
git commit -m "add: foo + mytool"
git push
APPLY=1 bash ./link.sh
```

# New machine bootstrap
```bash
git clone git@github.com:<USER>/<REPO>.git ~/dotfiles
cd ~/dotfiles
APPLY=1 bash ./link.sh
```

## Update workflow
```bash
# edit files ONLY in ~/dotfiles/...
git status
git add -A
git commit -m "tweak: hypr/waybar/etc"
git push

```

## Restore a backed-up file
```bash
ls -1 <target>.bak.*
mv <target>.bak.TIMESTAMP <target>

```

# Troubleshooting

**Missing config after reboot:**

- Check you’re using the right shell: echo "$SHELL"; chsh -s /bin/zsh if needed.

- Verify symlink: 'ls -l ~/.zshrc' → should point into '~/dotfiles/home/.zshrc'.

**Theme tools:**

- 'QT_QPA_PLATFORMTHEME=qt6ct' requires 'qt6ct'.

- 'QT_STYLE_OVERRIDE=kvantum' requires 'kvantum-qt6'.

### Notes

- Keep home/.zshrc with leading dot in the repo.

- Editor temp ignores (optional):
```markdown
*~
*.swp
*.tmp
.DS_Store
Thumbs.db

```


