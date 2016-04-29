#!/bin/bash

declare	-r SHA1_REGEXP="[[:xdigit:]]{40}"

# get_date_offset()
#  1> : date
#  2> : offset
# (3<): offset date
get_date_offset()
{
	(((2 <= $#) || ($# <= 3))) || die "Invalid argument count (2-3)"
	local	__BASE_DATE="${1}"
	local	__BASE_OFFSET="${2}"
	local	__OFFSET_DATE_RETVAR="${3}"

	[[ ! "${__BASE_OFFSET}" =~ ^(\+|\-) ]] && __BASE_OFFSET="+${__BASE_OFFSET}"
	local __OFFSET_DATE="$( date --rfc-3339=seconds -d "${__BASE_DATE}${__BASE_OFFSET}" ; (($?>0)) && die "date" )"
	[[ -z "${__OFFSET_DATE}" ]] && return 1
	if [[ -z ${__OFFSET_DATE_RETVAR} ]]; then
		echo "${__OFFSET_DATE}"
	else
		eval $__OFFSET_DATE_RETVAR="'${__OFFSET_DATE}'"
	fi
}

# get_git_commit_date()
#  1> : git tree directory
#  2> : git commit (SHA-1) hash
# (3<): git commit date
get_git_commit_date()
{
	(((2 <= $#) || ($# <= 3))) || die "Invalid argument count (2-3)"
	local	__GIT_DIR="${1}"
	local	__GIT_COMMIT="${2}"
	local	__GIT_COMMIT_DATE_RETVAR="${3}"

	[[ ! -z "${__GIT_DIR}" && "x${__GIT_DIR}" == "x${PWD}" ]] && unset -v __GIT_DIR
	[[ ! -z "${__GIT_DIR}" ]] && { pushd "${__GIT_DIR}" >/dev/null || die "pushd \"${__GIT_DIR}\""; }
	[[ -d "{PWD}/.git" ]] && die "Git tree not detected in directory \"${PWD}\" ."
	[[ "${__GIT_COMMIT}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (2): invalid SHA-1 git commit \"${__GIT_COMMIT}\""
	local __GIT_COMMIT_DATE="$( git show -s --format=%ci "${__GIT_COMMIT}" ; (($?>0)) && die "git show" )"
	[[ ! -z "${__GIT_DIR}" ]] && { popd >/dev/null || die "popd"; }
	[[ -z "${__GIT_COMMIT_DATE}" ]] && return 1
	if [[ -z ${__GIT_COMMIT_DATE_RETVAR} ]]; then
		echo "${__GIT_COMMIT_DATE}"
	else
		eval $__GIT_COMMIT_DATE_RETVAR="'${__GIT_COMMIT_DATE}'"
	fi
}

# get_sieved_git_commit_log()
#  1> : git tree directory
# (2>) : start date
# (3>) : end date
#  4<  : git commit log
get_sieved_git_commit_log()
{
	(((2 <= $#) || ($# <= 4))) || die "Invalid argument count (2-4)"
	local	__GIT_DIR="${1}"
	local	START_DATE="${2}"
	local	END_DATE="${3}"
	local	-a __GIT_LOG_ARRAY="${@: -1:1}"

	[[ ! -z "${__GIT_DIR}" && "x${__GIT_DIR}" == "x${PWD}" ]] && unset -v __GIT_DIR
	[[ ! -z "${__GIT_DIR}" ]] && { pushd "${__GIT_DIR}" >/dev/null || die "pushd \"${__GIT_DIR}\""; }
	[[ -d "{PWD}/.git" ]] && die "Git tree not detected in directory \"${PWD}\" ."
	local __GIT_LOG
	if [[ ${#} -eq 4 ]]; then
		__GIT_LOG="$( git log --format='%H,%P' --reverse --all --after "${START_DATE}" --before "${END_DATE}" ; (($?>0)) && die "git log" )"
	elif [[ ${#} -eq 3 ]]; then
		__GIT_LOG="$( git log --format='%H,%P' --reverse --all --after "${START_DATE}" ; (($?>0)) && die "git log" )"
	else
		__GIT_LOG="$( git log --format='%H,%P' --reverse --all  ; (($?>0)) && die "git log" )"
	fi
	[[ ! -z "${__GIT_DIR}" ]] && { popd >/dev/null || die "popd"; }
	eval ${__GIT_LOG_ARRAY}="( $(printf '%s' "${__GIT_LOG}" ) )"
}

# get_upstream_wine_commit()
#  1>  : Wine-Staging git tree directory
#  2>  : Wine-Staging commit
# (3<) : Upstream Wine commit
get_upstream_wine_commit()
{
	(((2 <= $#) || ($# <= 3))) || die "Invalid argument count (2-3)"
	local	WINE_STAGING_GIT_DIR="${1}"
	local	__TARGET_WINE_STAGING_COMMIT="${2}"
	local	__WINE_GIT_COMMIT_RETVAR="${3}"

	[[ "x${WINE_STAGING_GIT_DIR}" != "x${PWD}" ]] && local GIT_DIR="${WINE_STAGING_GIT_DIR}"
	[[ ! -z "${GIT_DIR}" ]] && { pushd "${GIT_DIR}" >/dev/null || die "pushd \"${GIT_DIR}\""; }
	[[ -d "{PWD}/.git" ]] && die "Wine-Staging git tree not detected in directory \"${PWD}\" ."
	[[ "${__TARGET_WINE_STAGING_COMMIT}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (2): invalid Wine-Staging SHA-1 git commit \"${__TARGET_WINE_STAGING_COMMIT}\""
	local -r PATCH_INSTALLER="patches/patchinstall.sh"
	git reset --hard --quiet "${__TARGET_WINE_STAGING_COMMIT}" || die "git reset"
	[[ -f "${PATCH_INSTALLER}" ]] || die "Unable to find Wine-Staging \"${PATCH_INSTALLER}\" script."
	local WINE_STAGING_VERSION=$( "${PATCH_INSTALLER}" --version 2>/dev/null; (($?>0)) && die "bash script \"${PATCH_INSTALLER}\"" )
	[[ ! -z "${GIT_DIR}" ]] && { popd >/dev/null || die "popd"; }
	local __WINE_GIT_COMMIT=$(printf '%s' "${WINE_STAGING_VERSION}" | awk '{ if ($1=="commit") print $2}' 2>/dev/null)
	if [[ ! "${__WINE_GIT_COMMIT}" =~ ${SHA1_REGEXP} ]]; then
		die "awk: failed to get Wine commit corresponding to Wine-Staging commit \"${__TARGET_WINE_STAGING_COMMIT}\" ."
	fi
	if [[ -z ${__WINE_GIT_COMMIT_RETVAR} ]]; then
		echo "${__WINE_GIT_COMMIT}"
	else
		eval $__WINE_GIT_COMMIT_RETVAR="'${__WINE_GIT_COMMIT}'"
	fi
}

# walk_wine_staging_git_tree()
#  1>  : Wine-Staging git tree directory
#  2>  : Wine git tree directory
#  3>  : Target Wine git commit (SHA-1) hash
# (4<) : Target Wine-Staging git commit (SHA-1) hash
walk_wine_staging_git_tree()
{
	(((3 <= $#) || ($# <= 4))) || die "Invalid argument count (3-4)"
	local	WINE_STAGING_GIT_DIR="${1}"
	local	WINE_GIT_DIR="${2}"
	local	__TARGET_WINE_COMMIT="${3}"
	local	__WINE_STAGING_COMMIT_RETVAR="${4}"

	local __TARGET_WINE_COMMIT_DATE=$(get_git_commit_date "${WINE_GIT_DIR}" "${__TARGET_WINE_COMMIT}")
	[[ "x${WINE_STAGING_GIT_DIR}" != "x${PWD}" ]] && local GIT_DIR="${WINE_STAGING_GIT_DIR}"
	[[ ! -z "${GIT_DIR}" ]] && { pushd "${GIT_DIR}" >/dev/null || die "pushd"; }
	[[ -d "{PWD}/.git" ]] && die "Wine-Staging git tree not detected in directory \"${PWD}\" ."
	[[ "${__TARGET_WINE_COMMIT}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (3): invalid Wine SHA-1 git commit \"${__TARGET_WINE_COMMIT}\""
	declare -a __WINE_STAGING_GIT_LOG_ARRAY
	get_sieved_git_commit_log "${WINE_STAGING_GIT_DIR}" "${__TARGET_WINE_COMMIT_DATE}" "__WINE_STAGING_GIT_LOG_ARRAY"
	local COMMITS_TOTAL=${#__WINE_STAGING_GIT_LOG_ARRAY[@]}
	local INDEX
	for (( INDEX=0 ; INDEX<COMMITS_TOTAL ; ++INDEX )); do
		local __PREV_WINE_STAGING_COMMIT="${__TARGET_WINE_STAGING_COMMIT:-${__WINE_STAGING_COMMIT}}"
        local __WINE_STAGING_COMMIT="${__WINE_STAGING_GIT_LOG_ARRAY[INDEX]:0:40}"
		local __WINE_STAGING_PARENT_COMMIT="${__WINE_STAGING_GIT_LOG_ARRAY[INDEX]:41:40}"
		if [[ -z "${__PREV_WINE_STAGING_COMMIT}" ]] || [[ "x${__WINE_STAGING_PARENT_COMMIT}" == "x${__PREV_WINE_STAGING_COMMIT}" ]]; then
			local __WINE_GIT_COMMIT=$(get_upstream_wine_commit "${WINE_STAGING_GIT_DIR}" "${__WINE_STAGING_COMMIT}")
			# keep searching even when we find a commit match (get most recent/matching Wine-Staging commit) ...
			[[ "x${__WINE_GIT_COMMIT}" == "x${__TARGET_WINE_COMMIT}" ]] && local __TARGET_WINE_STAGING_COMMIT="${__WINE_STAGING_COMMIT}"
		fi
	done
	unset __WINE_STAGING_GIT_LOG_ARRAY
	[[ ! -z "${__TARGET_WINE_STAGING_COMMIT}" ]] && { git reset --hard --quiet "${__TARGET_WINE_STAGING_COMMIT}" || die "git reset"; }
	[[ ! -z "${GIT_DIR}" ]] && { popd >/dev/null || die "popd"; }
	[[ -z "${__TARGET_WINE_STAGING_COMMIT}" ]] && return 1
	if [[ -z ${__WINE_STAGING_COMMIT_RETVAR} ]]; then
		echo "${__TARGET_WINE_STAGING_COMMIT}"
	else
		eval $__WINE_STAGING_COMMIT_RETVAR="'${__TARGET_WINE_STAGING_COMMIT}'"
	fi
}

# find_closest_wine_commit()
#  1>  : Wine-Staging git tree directory
#  2>  : Wine git tree directory
#  3<> : Target Wine git commit (SHA-1) hash
#  4<  : Target Wine-Staging git commit (SHA-1) hash
#  5< : Wine git tree commit offset
find_closest_wine_commit()
{
	(($# == 5)) || die "Invalid argument count (5)"
	local	WINE_STAGING_GIT_DIR="${1}"
	local	WINE_GIT_DIR="${2}"
	local	__WINE_COMMIT_RETVAR="${3}"
	local	__WINE_STAGING_COMMIT_RETVAR="${4}"
	local	__WINE_COMMIT_DIFF_RETVAR="${5}"

	# Search is weighted to preceeding time period - since Wine-Staging git is delayed in tracking Wine git tree
	local -r WINE_GIT_DATE_ROFFSET="-2 weeks"
	local -r WINE_GIT_DATE_FOFFSET="+1 week"
	[[ "x${WINE_GIT_DIR}" != "x${PWD}" ]] && local GIT_DIR="${WINE_GIT_DIR}"
	[[ ! -z "${GIT_DIR}" ]] && { pushd "${GIT_DIR}" || die "pushd"; }
	[[ -d "{PWD}/.git" ]] && die "Wine git tree not detected in directory \"${PWD}\" ."
	[[ "${!__WINE_COMMIT_RETVAR}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (3): invalid Wine SHA-1 git commit \"${!__WINE_COMMIT_RETVAR}\""
	declare -a __WINE_GIT_LOG_ARRAY
	local __WINE_COMMIT_DATE=$( get_git_commit_date "${WINE_GIT_DIR}" "${!__WINE_COMMIT_RETVAR}" )
	local __WINE_REVERSE_DATE_LIMIT=$( get_date_offset "${__WINE_COMMIT_DATE}" "${WINE_GIT_DATE_ROFFSET}" )
	local __WINE_FORWARD_DATE_LIMIT=$( get_date_offset "${__WINE_COMMIT_DATE}" "${WINE_GIT_DATE_FOFFSET}" )
	get_sieved_git_commit_log "${WINE_GIT_DIR}" "${__WINE_REVERSE_DATE_LIMIT}" "${__WINE_FORWARD_DATE_LIMIT}" "__WINE_GIT_LOG_ARRAY"
	local COMMITS_TOTAL=${#__WINE_GIT_LOG_ARRAY[@]}
	local PRE_INDEX=-1
	local POST_INDEX=${COMMITS_TOTAL}
	local INDEX
	for INDEX in "${!__WINE_GIT_LOG_ARRAY[@]}"; do
		[[ "x${!__WINE_COMMIT_RETVAR}" == "x${__WINE_GIT_LOG_ARRAY[INDEX]:0:40}" ]] && break
	done
	(( ($? == 0) && ( PRE_INDEX=POST_INDEX=INDEX ) ))
	while (( (0<=PRE_INDEX) || (POST_INDEX<COMMITS_TOTAL) )); do
		# Go backwards
		if (( PRE_INDEX >= 0 )); then
			local PRE_COMMIT_TARGET_CHILD="${__WINE_GIT_LOG_ARRAY[PRE_INDEX]:41:40}"
			while (( --PRE_INDEX >= 0 )); do
				[[ "x${PRE_COMMIT_TARGET_CHILD}" == "x${__WINE_GIT_LOG_ARRAY[PRE_INDEX]:0:40}" ]] && break
			done
			if (( PRE_INDEX >= 0 )); then
				local TARGET_WINE_COMMIT="${__WINE_GIT_LOG_ARRAY[PRE_INDEX]:0:40}"
				local __WINE_COMMIT_DIFF=$(( PRE_INDEX - INDEX ))
				local TARGET_WINE_STAGING_COMMIT
				walk_wine_staging_git_tree "${WINE_STAGING_GIT_DIR}" "${WINE_GIT_DIR}" "${TARGET_WINE_COMMIT}" "TARGET_WINE_STAGING_COMMIT" \
					&& break
			fi
		fi
		# Go forwards
		if (( POST_INDEX < COMMITS_TOTAL )); then
			local POST_COMMIT_TARGET_PARENT="${__WINE_GIT_LOG_ARRAY[POST_INDEX]:0:40}"
			while (( ++POST_INDEX < COMMITS_TOTAL )); do
				[[ "x${POST_COMMIT_TARGET_PARENT}" == "x${__WINE_GIT_LOG_ARRAY[POST_INDEX]:41:40}" ]] && break
			done
			if (( POST_INDEX < COMMITS_TOTAL )); then
				local TARGET_WINE_COMMIT="${__WINE_GIT_LOG_ARRAY[POST_INDEX]:0:40}"
				local __WINE_COMMIT_DIFF=$(( POST_INDEX - INDEX ))
				local TARGET_WINE_STAGING_COMMIT
				walk_wine_staging_git_tree "${WINE_STAGING_GIT_DIR}" "${WINE_GIT_DIR}"  "${TARGET_WINE_COMMIT}" "TARGET_WINE_STAGING_COMMIT" \
					&& break
			fi
		fi
	done
	unset -v __WINE_GIT_LOG_ARRAY
	[[ ! -z "${GIT_DIR}" ]] && { popd || die; }
	[[ -z "${TARGET_WINE_STAGING_COMMIT}" ]] && return 1
	eval $__WINE_COMMIT_RETVAR="'${TARGET_WINE_COMMIT}'"
	eval $__WINE_STAGING_COMMIT_RETVAR="'${TARGET_WINE_STAGING_COMMIT}'"
	[[ -z "{$__WINE_COMMIT_DIFF_RETVAR}" ]] || eval $__WINE_COMMIT_DIFF_RETVAR="'${__WINE_COMMIT_DIFF}'"
}

# display_closest_wine_commit_message()
# 1>  : Target Wine git commit (SHA-1) hash
# 2>  : Target Wine-Staging git commit (SHA-1) hash
# 3>  : Wine git tree commit offset
display_closest_wine_commit_message()
{
	((${#}==3)) || die "Invalid argument count (3)"
	local	__TARGET_WINE_COMMIT="${1}"
	local	__TARGET_WINE_STAGING_COMMIT="${2}"
	local	__WINE_COMMIT_DIFF="${3}"

	[[ "${__TARGET_WINE_COMMIT}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (1): invalid Wine SHA-1 git commit \"${__TARGET_WINE_COMMIT}\""
	[[ "${__TARGET_WINE_STAGING_COMMIT}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (2): invalid Wine-Staging SHA-1 git commit \"${__TARGET_WINE_STAGING_COMMIT}\""
	if (( __WINE_COMMIT_DIFF < 0 )); then
		__WINE_COMMIT_DIFF=$((-__WINE_COMMIT_DIFF))
		local DIFF_MESSAGE="offset ${__WINE_COMMIT_DIFF} commits back"
	elif (( __WINE_COMMIT_DIFF > 0 )); then
		local DIFF_MESSAGE="offset ${__WINE_COMMIT_DIFF} commits foward"
	else
		local DIFF_MESSAGE="no offset"
	fi
	(( __WINE_COMMIT_DIFF == 1 )) && DIFF_MESSAGE="${DIFF_MESSAGE/commits /commit }"

	eerror "Try rebuilding this package using the closest supported Wine commit (${DIFF_MESSAGE}):"
	eerror "        EGIT_COMMIT=\"${__TARGET_WINE_COMMIT}\" emerge -v =${CATEGORY}/${P}  # build against Wine commit"
	eerror "... or:"
	eerror "EGIT_STAGING_COMMIT=\"${__TARGET_WINE_STAGING_COMMIT}\" emerge -v =${CATEGORY}/${P}  # build against Wine-Staging commit"
	eerror
}
