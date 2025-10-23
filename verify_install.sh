#!/bin/bash
set -euo pipefail
trap 'echo "Error: command failed on line $LINENO: $BASH_COMMAND" >&2' ERR

# Declare an associative array keyed by the generic package name to install, with
# a value of all the architecture packages expected to be found if installed.
declare -A package_map
package_map[dnf-plugins-core]="dnf-plugins-core.noarch"
package_map[gcc]="gcc.x86_64"
package_map[git]="git.x86_64 git-core.x86_64"
package_map[make]="make.x86_64"
package_map[wget]="wget.x86_64"
package_map[openssl-devel]="openssl-devel.x86_64"
package_map[bzip2-devel]="bzip2-devel.x86_64"
package_map[libffi-devel]="libffi-devel.x86_64"
package_map[zlib-devel]="zlib-ng-compat-devel.x86_64"
package_map[xz-devel]="xz-devel.x86_64"
package_map[procps-ng]="procps-ng.x86_64"

# Declare an associative array keyed by the generic package name to install, with
# a value of all the architecture packages expected to be found if installed.
declare -A py_pkg_map
py_pkg_map[pip]="pip"
py_pkg_map[wheel]="wheel"
py_pkg_map[uwsgi]="uWSGI"

# Use emojis while tracking verification steps if the LANG
# environment variable is set to 'UTF-8' or 'utf8' (case-insensitive).
declare -A emoji_map
if echo "$LANG" | grep -iEq 'utf[-]?8' > /dev/null; then
    # Locale is UTF-8 compatible, set emojis
    emoji_map[key]='🔑'
    emoji_map[pkg]='📦'
    emoji_map[success]='✅'
else
    # Locale is not UTF-8 compatible, set empty strings
    emoji_map[key]=''
    emoji_map[pkg]=''
    emoji_map[success]=''
fi

# grab the list of installed packages to search
DNF_LIST_OUTPUT=$(dnf list 2>/dev/null)

echo Make sure subscription-manager.conf changes in place
echo "${emoji_map[key]}Check if suppressing of entitlements is configured..."
grep -Pzo '\[main\]\nenabled=0\n' /etc/dnf/plugins/subscription-manager.conf > /dev/null
[ $? -eq 0 ] && echo "...${emoji_map[success]}okay!";
echo "${emoji_map[key]}Check if external repos enabled regardless of subscription..."
grep -Pzo '\ndisable_system_repos=0' /etc/dnf/plugins/subscription-manager.conf > /dev/null
[ $? -eq 0 ] && echo "...${emoji_map[success]}okay!";

echo Make sure expected packages have been installed with dnf
for package_key in "${!package_map[@]}"; do
    echo "${emoji_map[key]}Check if ${package_key} (Generic Name) installed..."
    # Get the string containing all space-separated values for the current key
    package_values="${package_map[${package_key}]}"
    for arch_value in ${package_values}; do
	echo -n "   ${emoji_map[pkg]}looking for ${arch_value}"
	grep -E "^${arch_value}[[:space:]].*$" > /dev/null <<< "$DNF_LIST_OUTPUT"
	[ $? -eq 0 ] && echo "...${emoji_map[success]}found!";
    done
done

echo Make sure expected Python packages have been installed with pip
# grab the list of installed packages to search
PIP_LIST_OUTPUT=$(/usr/local/bin/pip3.13 list --no-cache-dir 2> /dev/null)
for py_pkg_key in "${!py_pkg_map[@]}"; do
    echo "${emoji_map[key]}Check if ${py_pkg_key} Python package installed..."
    # Get the string containing all space-separated values for the current key
    package_values="${py_pkg_map[${py_pkg_key}]}"
    for pkg_name in ${package_values}; do
	echo -n "   ${emoji_map[pkg]}looking for ${pkg_name}"
	grep -E "^${pkg_name}[[:space:]].*$" > /dev/null <<< "$PIP_LIST_OUTPUT"
	[ $? -eq 0 ] && echo "...${emoji_map[success]}found!";
    done
done

# @TODO Make sure alternatives settings and shell-user aliases are as expected
# /etc/profile.d/uwsgi_python.sh
# which python3 python pip3 pip

# @TODO Make sure su-exec installed and usable by root
# su-exec --help
# Usage: su-exec user-spec command [args]
# su-exec hive ls
# su-exec: getpwnam(hive): Success

echo No verification errors trapped. Checked results are as expected.
exit 0
