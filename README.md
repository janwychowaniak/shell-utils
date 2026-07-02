# shell-utils

This repository contains a collection of bash scripts that automate or otherwise help accelerate some typical day to day activities related, among other things, to:

* navigating file system and working with files
* working with media material
* performing some helpful programming tasks
* managing Python virtual environments, packages and projects (uv / pip / pipx)

## Installation suggestions

E.g. in `~/bin`:

```bash
cd ~/bin
git clone https://github.com/janwychowaniak/shell-utils.git
```
And then `.bashrc` (or `.zshrc` — the snippet is identical for both shells) might be appended with the following:

```bash
[[ -f "$HOME/bin/shell-utils/jw_aliases.sh" ]]            && . "$HOME/bin/shell-utils/jw_aliases.sh"
[[ -f "$HOME/bin/shell-utils/jw_colors.sh" ]]             && . "$HOME/bin/shell-utils/jw_colors.sh"
#
[[ -f "$HOME/bin/shell-utils/jw_functions__docker.sh" ]]  && . "$HOME/bin/shell-utils/jw_functions__docker.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__git.sh" ]]     && . "$HOME/bin/shell-utils/jw_functions__git.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__deb.sh" ]]     && . "$HOME/bin/shell-utils/jw_functions__deb.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__python.sh" ]]  && . "$HOME/bin/shell-utils/jw_functions__python.sh"
#
[[ -f "$HOME/bin/shell-utils/jw_functions__web.sh" ]]     && . "$HOME/bin/shell-utils/jw_functions__web.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__files.sh" ]]   && . "$HOME/bin/shell-utils/jw_functions__files.sh"
#
[[ -f "$HOME/bin/shell-utils/jw_functions__fs.sh" ]]      && . "$HOME/bin/shell-utils/jw_functions__fs.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__media.sh" ]]   && . "$HOME/bin/shell-utils/jw_functions__media.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__mediaff.sh" ]] && . "$HOME/bin/shell-utils/jw_functions__mediaff.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__mediaim.sh" ]] && . "$HOME/bin/shell-utils/jw_functions__mediaim.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__misc.sh" ]]    && . "$HOME/bin/shell-utils/jw_functions__misc.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__prog.sh" ]]    && . "$HOME/bin/shell-utils/jw_functions__prog.sh"
```
