# Copilot Prompts For Common Tasks

## File Structure (per Library)

```bash
tree -L 3 langs/
langs/
├── ai-skill
│   ├── copilot_common_library.md
│   ├── copilot_prompt_playbook.md
│   └── copilot_roi_template.md
├── bash-lang
├── js-lang
├── perl-lang
│   ├── arguments
│   │   └── getopts_long.pl
│   ├── command_exec
│   │   └── ipc_run3.pl
│   ├── file_find_rule.pl
│   ├── json
│   │   └── json.pl
│   ├── patterns.pl
│   └── re.pl
├── plsql-lang
└── python-lang
 └── arguments
 ├── argparse.py
 ├── click.py
 └── typer.py
```

## Example:

# Prompt: Create an Ansible Playbook for User Management

**Prompt:**

> Generate an Ansible playbook that creates a Linux user, assigns it to the `devops` group, ensures idempotency, and logs actions.

**Copilot Output Summary:**

- Creates user if not exists

- Adds to group

- Uses handlers to restart sshd if config changes

**Notes:**

Good initial result. Add task tags, and verify become permissions.
