---
name: github-auto-repo
description: Create a GitHub repository with the same name as the current folder. Use `--private` for private repository; default is public.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(grep:*), Bash(basename:*), Bash(pwd:*)
user-invocable: true
---

## Context

- Arguments: `$ARGUMENTS` (empty for public, `--private` for private)
- Current folder: !`basename $(pwd)`
- Git status: !`git rev-parse --is-inside-work-tree 2>/dev/null && echo "valid" || echo "invalid"`
- Authentication: !`gh auth status 2>&1 | head -1`

## Task

Create a GitHub repository with the same name as the current directory. Optionally support `--private` flag for private repositories; default to public.

### Phase 1-2: Shared Validation & Setup

#### Verify Git Repository

Check if current directory is a valid git repository:

```bash
if ! git rev-parse --is-inside-work-tree 2>/dev/null; then
  echo "Error: Not a git repository."
  exit 2
fi
```

#### Verify GitHub Authentication

Check GitHub CLI authentication status:

```bash
if ! gh auth status >/dev/null 2>&1; then
  echo "Error: GitHub authentication failed."
  exit 3
fi
```

#### Get and Sanitize Folder Name

Extract current directory name and sanitize for GitHub repository naming:

```bash
# Get folder name (e.g., "My Project!!!" → "My Project!!!")
folder_name=$(basename $(pwd))

# Sanitize: spaces → hyphens, remove special chars, lowercase, limit to 39 chars
sanitized_name=$(echo "$folder_name" | \
  sed 's/ /-/g' | \
  sed 's/[^a-zA-Z0-9-_]//g' | \
  tr '[:upper:]' '[:lower:]' | \
  cut -c1-39)

# If sanitized name is empty, try parent directory
if [ -z "$sanitized_name" ]; then
  parent_name=$(basename $(dirname $(pwd)))
  sanitized_name=$(echo "$parent_name" | \
    sed 's/ /-/g' | \
    sed 's/[^a-zA-Z0-9-_]//g' | \
    tr '[:upper:]' '[:lower:]' | \
    cut -c1-39)
fi

# If still empty, error
if [ -z "$sanitized_name" ]; then
  echo "Error: Folder name cannot be converted to a valid repository name."
  exit 5
fi
```

#### Parse Visibility Flag

Determine repository visibility from arguments:

```bash
visibility="public"
if echo "$ARGUMENTS" | grep -q "\--private"; then
  visibility="private"
fi
```

#### Check for Duplicate Repository

Verify repository doesn't already exist on GitHub:

```bash
if gh repo list --source | cut -f1 | grep -q "^${sanitized_name}$"; then
  echo "Error: Repository '${sanitized_name}' already exists on GitHub."
  exit 4
fi
```

### Phase 3 & 4: Repository Creation (Public & Private)

#### Create Repository on GitHub

Create repository with specified visibility:

```bash
if [ "$visibility" = "private" ]; then
  gh repo create "${sanitized_name}" --private --source=. --remote=origin 2>&1
else
  gh repo create "${sanitized_name}" --public --source=. --remote=origin 2>&1
fi

if [ $? -ne 0 ]; then
  echo "Error: Failed to create repository. Check your permissions or network."
  exit 7
fi
```

#### Create and Push Branches

Ensure main branch and create develop branch:

```bash
# Create develop branch locally
git checkout -b develop 2>/dev/null || git checkout develop

# Push both main and develop to origin
if ! git push origin main develop 2>&1; then
  echo "Error: Failed to push branches to GitHub."
  exit 7
fi
```

### Success Output

Display completion message:

```bash
# Get repository URL from GitHub
repo_url=$(gh repo view --json url --jq .url)

# Display success message
echo "✓ Repository created successfully"
echo "  Name: ${sanitized_name}"
echo "  Visibility: ${visibility}"
echo "  Remote: origin"
echo "  URL: ${repo_url}"
echo "  Branches: main, develop"
```

### Complete Implementation

The full implementation combines all phases above into a single, atomic operation:

1. Verify git repository exists
2. Verify GitHub authentication works
3. Get and sanitize folder name (with fallback to parent)
4. Parse `--private` flag for visibility
5. Check for existing repository (prevent duplicates)
6. Create repository on GitHub with correct visibility
7. Push branches to origin
8. Display success message with repository details

All error conditions exit with appropriate codes and display simple, actionable error messages (no recovery suggestions).

---

## Exit Codes

- **0**: Success
- **2**: Not a git repository
- **3**: GitHub authentication failed
- **4**: Repository already exists
- **5**: Invalid repository name (cannot be sanitized)
- **6**: No permission to create repositories
- **7**: Network error or push failure

## Error Handling

All errors display simple messages without recovery steps:

- "Error: Not a git repository."
- "Error: GitHub authentication failed."
- "Error: Repository 'name' already exists on GitHub."
- "Error: Folder name cannot be converted to a valid repository name."
- "Error: Failed to create repository. Check your permissions or network."

---

## Examples

### Create Public Repository

```bash
$ cd my-project
$ /github-auto-repo
✓ Repository created successfully
  Name: my-project
  Visibility: public
  Remote: origin
  URL: https://github.com/user/my-project.git
  Branches: main, develop
```

### Create Private Repository

```bash
$ cd secret-project
$ /github-auto-repo --private
✓ Repository created successfully
  Name: secret-project
  Visibility: private
  Remote: origin
  URL: https://github.com/user/secret-project.git
  Branches: main, develop
```

### Error: Not a Git Repository

```bash
$ cd /tmp
$ /github-auto-repo
Error: Not a git repository.
$ echo $?
2
```

### Error: Repository Already Exists

```bash
$ cd existing-project
$ /github-auto-repo
Error: Repository 'existing-project' already exists on GitHub.
$ echo $?
4
```
