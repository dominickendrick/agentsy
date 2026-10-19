Agentsy
=======

> Support and empower engineers' use of Agentic AI.

Agentsy exposes useful AI tooling inside a development environment, typically a
dev container. It currently supports scripts and GitHub Copilot CLI
instructions, and it is also a GitHub Copilot CLI plugin marketplace.

## Installation

Clone this repository and run `agentsy install` from the checkout to make the
`agentsy` command available in your terminal:

```bash
git clone https://github.com/guardian/agentsy.git ~/agentsy
~/agentsy/agentsy install
```

If your project uses the Agentsy module in
[devenv](https://github.com/guardian/devenv), devenv clones and installs Agentsy
for you.

To remove the `agentsy` command, run `agentsy uninstall`. This leaves the
checkout and any enabled features in place.

## Usage

Run `agentsy` without arguments in an interactive terminal to open the feature
manager:

```console
$ agentsy
```

In interactive mode, use the `Up` and `Down` arrow keys to select a feature,
`Space` to enable or disable it, and `q` or `Esc` to exit. The interface shows
`[x]` for enabled features and `[!]` when a feature with that name already
exists at the destination.

You can also use the following commands to manage features:

```bash
agentsy list
agentsy list --type instructions
agentsy enable script openai-copilot
agentsy enable instructions writing-style.instructions.md
agentsy disable instructions writing-style.instructions.md
```

`enable` creates an absolute symlink from the feature in this checkout to the
location used by the dev container:

| Type         | Destination                          |
|--------------|--------------------------------------|
| Script       | `~/.local/bin/<name>`                |
| Instructions | `~/.copilot/instructions/<filename>` |

Running the same `enable` or `disable` command more than once is safe. Agentsy
does not replace existing paths that it does not manage, and it only removes
links to features in the current checkout.

## Features

### Instructions

#### Writing style instructions

The `writing-style.instructions.md` file gives Copilot guidance for plain
repository documentation, comments, commit messages, and pull request
descriptions.

### Scripts

#### OpenAI-backed Copilot CLI

The `openai-copilot` script runs GitHub Copilot CLI against a supported OpenAI
model using Copilot's BYOK support. It requires `copilot` on `PATH` and
`OPENAI_API_KEY` in the environment.

```bash
openai-copilot <model_id> [copilot_args...]
```

Supported model IDs are grouped by family:

| Family    | Available model IDs                            |
|-----------|------------------------------------------------|
| `gpt-5.6` | `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna` |
| `gpt-6`   | `gpt-6-astra`, `gpt-6-luna`, `gpt-6-sol`       |
| `gpt-6.1` | `gpt-6.1-sol`                                  |

For `gpt-6.1-sol`, the script uses `gpt-6-sol` for Copilot's agent configuration
and sends `gpt-6.1-sol` to OpenAI. All other supported models use the requested
model ID for both agent configuration and OpenAI requests.

## Plugin marketplace

This repository is a GitHub Copilot CLI plugin marketplace, which is defined in
[`.github/plugin/marketplace.json`](.github/plugin/marketplace.json).

To test this, add the marketplace to Copilot CLI and then install a plugin from it with:

```bash
copilot plugin marketplace add guardian/agentsy
copilot plugin install simplify-goal@agentsy
```

A new slash command `/simplify-goal` should now be available in your CLI session.

## Development

### TUI style guide

The repository's terminal output conventions are documented in
[`STYLE_GUIDE.md`](STYLE_GUIDE.md). This style guide is implemented in
[terminal-style.sh](scripts/lib/terminal-style.sh).

### Validation

Run the dependency-free shell tests and ShellCheck with:

```bash
tests/agentsy-test.sh
shellcheck agentsy scripts/openai-copilot scripts/lib/*.sh tests/*.sh
```
