# this is only meant to be included, not used directly

# checks if branch has something pending
function parse_git_dirty() {
  git diff --quiet --ignore-submodules HEAD 2>/dev/null; [ $? -eq 1 ] && echo "true" && return
  echo "false"
}

# gets the current git branch
function parse_git_branch() {
  git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1/" -e "s/.*HEAD detached at \(.*\))/\1/"
}

# gets the latest git tag
function parse_git_latest_tag() {
	git describe --tags --abbrev=0 2> /dev/null
}

# get last commit hash prepended with @ (i.e. @8a323d0)
function parse_git_hash() {
  git rev-parse --short HEAD 2> /dev/null | sed "s/\(.*\)/@\1/"
}

# Output
GIT_LATEST_TAG=$(parse_git_latest_tag)
GIT_BRANCH=$(parse_git_branch)
GIT_HASH=$(parse_git_hash)
GIT_DIRTY=$(parse_git_dirty)

# this is modeled after a revision format like the following: v1.2.3-rc0_test4
APP_VERSION_MAJOR=$(echo -n "${GIT_LATEST_TAG}"  | cut -d. -f1 |sed -e 's/[^0-9]//g')
APP_VERSION_MINOR=$(echo -n "${GIT_LATEST_TAG}"  | cut -d. -f2 |sed -e 's/[^0-9]//g')
APP_VERSION_BUILD=$(echo -n "${GIT_LATEST_TAG}"  | cut -d. -f3 | cut -d- -f1 |sed -e 's/[^0-9]//g')
APP_VERSION_RC=$(echo -n "${GIT_LATEST_TAG}"  | cut -d. -f3 | cut -d- -f2 | cut -d_ -f1 |sed -e 's/[^0-9]//g')
APP_VERSION_SPECIAL=$(echo -n "${GIT_LATEST_TAG}"  | cut -d. -f3 | cut -d- -f2 | cut -d_ -f1 |sed -e 's/[^0-9]//g')

# represents a semversion as a decimal for use with the nordic DFU non-semver logic
# uses 2 digits for each semver field, 1 for SPECIAL. This guarantees we don't break the 32 bit max
# The major is always incremented by 10 (e.g. rev 0 is 10, rev 12 is 22): this is an ugly kludge due to the fact that
# the resulting decimal cannot start with zero, otherwise the DFU will read the number as octal, and it must have a fixed
# number of digits (otherwise not having one of the optional components, e.g. RC, would make the release look older than the
# it is.
# this does not return a newline at the end of the sting.
# e.g. v1.2.3-rc0_test4 is represented as "110203004"
# e.g. v2.23.3 is represented as "122303000"
function get_tag_as_integer() {
  printf "%02u%02u%02u%02u%01u" "$((APP_VERSION_MAJOR + 10))" \
                                "${APP_VERSION_MINOR}" \
                                "${APP_VERSION_BUILD}" \
                                "${APP_VERSION_RC}" \
                                "${APP_VERSION_SPECIAL}"
}