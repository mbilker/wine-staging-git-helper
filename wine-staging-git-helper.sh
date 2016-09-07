#!/bin/bash

declare	-r SHA1_REGEXP="[[:xdigit:]]{40}"

# get_date_offset()
#  1> : date
#  2> : offset
# (3<): offset date
get_date_offset()
{
	(((2 <= $#) || ($# <= 3))) || die "Invalid argument count (2-3)"
	local	__base_date="${1}"
	local	__base_offset="${2}"
	local	__offset_date_retvar="${3}"

	[[ ! "${__base_offset}" =~ ^(\+|\-) ]] && __base_offset="+${__base_offset}"
	local __offset_date="$( date --rfc-3339=seconds -d "${__base_date}${__base_offset}" ; (($?>0)) && die "date" )"
	[[ -z "${__offset_date}" ]] && return 1
	if [[ -z ${__offset_date_retvar} ]]; then
		echo "${__offset_date}"
	else
		eval $__offset_date_retvar="'${__offset_date}'"
	fi
}

# get_git_commit_date()
#  1> : git tree directory
#  2> : git commit (SHA-1) hash
# (3<): git commit date
get_git_commit_date()
{
	(((2 <= $#) || ($# <= 3))) || die "Invalid argument count (2-3)"
	local	__git_dir="${1}"
	local	__git_commit="${2}"
	local	__git_commit_date_retvar="${3}"

	[[ ! -z "${__git_dir}" && "x${__git_dir}" == "x${PWD}" ]] && unset -v __git_dir
	[[ ! -z "${__git_dir}" ]] && { pushd "${__git_dir}" >/dev/null || die "pushd \"${__git_dir}\""; }
	[[ -d "{PWD}/.git" ]] && die "Git tree not detected in directory \"${PWD}\" ."
	[[ "${__git_commit}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (2): invalid SHA-1 git commit \"${__git_commit}\""
	local __git_commit_date="$( git show -s --format=%ci "${__git_commit}" ; (($?>0)) && die "git show" )"
	[[ ! -z "${__git_dir}" ]] && { popd >/dev/null || die "popd"; }
	[[ -z "${__git_commit_date}" ]] && return 1
	if [[ -z ${__git_commit_date_retvar} ]]; then
		echo "${__git_commit_date}"
	else
		eval $__git_commit_date_retvar="'${__git_commit_date}'"
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
	local	__git_dir="${1}"
	local	start_date="${2}"
	local	end_date="${3}"
	local	-a __git_log_array="${@: -1:1}"

	[[ ! -z "${__git_dir}" && "x${__git_dir}" == "x${PWD}" ]] && unset -v __git_dir
	[[ ! -z "${__git_dir}" ]] && { pushd "${__git_dir}" >/dev/null || die "pushd \"${__git_dir}\""; }
	[[ -d "{PWD}/.git" ]] && die "Git tree not detected in directory \"${PWD}\" ."
	local __git_log
	if [[ ${#} -eq 4 ]]; then
		__git_log="$( git log --format='%H,%P' --reverse --all --after "${start_date}" --before "${end_date}" ; (($?>0)) && die "git log" )"
	elif [[ ${#} -eq 3 ]]; then
		__git_log="$( git log --format='%H,%P' --reverse --all --after "${start_date}" ; (($?>0)) && die "git log" )"
	else
		__git_log="$( git log --format='%H,%P' --reverse --all  ; (($?>0)) && die "git log" )"
	fi
	[[ ! -z "${__git_dir}" ]] && { popd >/dev/null || die "popd"; }
	eval ${__git_log_array}="( $(printf '%s' "${__git_log}" ) )"
}

# get_upstream_wine_commit()
#  1>  : Wine-Staging git tree directory
#  2>  : Wine-Staging commit
# (3<) : Upstream Wine commit
get_upstream_wine_commit()
{
	(((2 <= $#) || ($# <= 3))) || die "Invalid argument count (2-3)"
	local	wine_staging_git_dir="${1}"
	local	__target_wine_staging_commit="${2}"
	local	__wine_git_commit_retvar="${3}"

	[[ "x${wine_staging_git_dir}" != "x${PWD}" ]] && local git_dir="${wine_staging_git_dir}"
	[[ ! -z "${git_dir}" ]] && { pushd "${git_dir}" >/dev/null || die "pushd \"${git_dir}\""; }
	[[ -d "{PWD}/.git" ]] && die "Wine-Staging git tree not detected in directory \"${PWD}\" ."
	[[ "${__target_wine_staging_commit}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (2): invalid Wine-Staging SHA-1 git commit \"${__target_wine_staging_commit}\""
	local -r patch_installer="patches/patchinstall.sh"
	git reset --hard --quiet "${__target_wine_staging_commit}" || die "git reset"
	[[ -f "${patch_installer}" ]] || die "Unable to find Wine-Staging \"${patch_installer}\" script."
	local wine_staging_version=$( "${patch_installer}" --version 2>/dev/null; (($?>0)) && die "bash script \"${patch_installer}\"" )
	[[ ! -z "${git_dir}" ]] && { popd >/dev/null || die "popd"; }
	local __wine_git_commit=$(printf '%s' "${wine_staging_version}" | awk '{ if ($1=="commit") print $2}' 2>/dev/null)
	if [[ ! "${__wine_git_commit}" =~ ${SHA1_REGEXP} ]]; then
		die "awk: failed to get Wine commit corresponding to Wine-Staging commit \"${__target_wine_staging_commit}\" ."
	fi
	if [[ -z ${__wine_git_commit_retvar} ]]; then
		echo "${__wine_git_commit}"
	else
		eval $__wine_git_commit_retvar="'${__wine_git_commit}'"
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
	local	wine_staging_git_dir="${1}"
	local	wine_git_dir="${2}"
	local	__target_wine_commit="${3}"
	local	__wine_staging_commit_retvar="${4}"

	local __target_wine_commit_date=$(get_git_commit_date "${wine_git_dir}" "${__target_wine_commit}")
	[[ "x${wine_staging_git_dir}" != "x${PWD}" ]] && local git_dir="${wine_staging_git_dir}"
	[[ ! -z "${git_dir}" ]] && { pushd "${git_dir}" >/dev/null || die "pushd"; }
	[[ -d "{PWD}/.git" ]] && die "Wine-Staging git tree not detected in directory \"${PWD}\" ."
	[[ "${__target_wine_commit}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (3): invalid Wine SHA-1 git commit \"${__target_wine_commit}\""
	declare -a __wine_staging_git_log_array
	get_sieved_git_commit_log "${wine_staging_git_dir}" "${__target_wine_commit_date}" "__wine_staging_git_log_array"
	local commit_total=${#__wine_staging_git_log_array[@]}
	local index
	for (( index=0 ; index<commit_total ; ++index )); do
		local __prev_wine_staging_commit="${__target_wine_staging_commit:-${__wine_staging_commit}}"
        local __wine_staging_commit="${__wine_staging_git_log_array[index]:0:40}"
		local __wine_staging_parent_commit="${__wine_staging_git_log_array[index]:41:40}"
		if [[ -z "${__prev_wine_staging_commit}" ]] || [[ "x${__wine_staging_parent_commit}" == "x${__prev_wine_staging_commit}" ]]; then
			local __wine_git_commit=$(get_upstream_wine_commit "${wine_staging_git_dir}" "${__wine_staging_commit}")
			# keep searching even when we find a commit match (get most recent/matching Wine-Staging commit) ...
			[[ "x${__wine_git_commit}" == "x${__target_wine_commit}" ]] && local __target_wine_staging_commit="${__wine_staging_commit}"
		fi
	done
	unset __wine_staging_git_log_array
	[[ ! -z "${__target_wine_staging_commit}" ]] && { git reset --hard --quiet "${__target_wine_staging_commit}" || die "git reset"; }
	[[ ! -z "${git_dir}" ]] && { popd >/dev/null || die "popd"; }
	[[ -z "${__target_wine_staging_commit}" ]] && return 1
	if [[ -z ${__wine_staging_commit_retvar} ]]; then
		echo "${__target_wine_staging_commit}"
	else
		eval $__wine_staging_commit_retvar="'${__target_wine_staging_commit}'"
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
	local	wine_staging_git_dir="${1}"
	local	wine_git_dir="${2}"
	local	__wine_commit_retvar="${3}"
	local	__wine_staging_commit_retvar="${4}"
	local	__wine_commit_diff_retvar="${5}"

	# Search is weighted to preceeding time period - since Wine-Staging git is delayed in tracking Wine git tree
	local -r wine_git_date_roffset="-2 weeks"
	local -r wine_git_date_foffset="+1 week"
	[[ "x${wine_git_dir}" != "x${PWD}" ]] && local git_dir="${wine_git_dir}"
	[[ ! -z "${git_dir}" ]] && { pushd "${git_dir}" || die "pushd"; }
	[[ -d "{PWD}/.git" ]] && die "Wine git tree not detected in directory \"${PWD}\" ."
	[[ "${!__wine_commit_retvar}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (3): invalid Wine SHA-1 git commit \"${!__wine_commit_retvar}\""
	declare -a __wine_git_log_array
	local __wine_commit_date=$( get_git_commit_date "${wine_git_dir}" "${!__wine_commit_retvar}" )
	local __wine_reverse_date_limit=$( get_date_offset "${__wine_commit_date}" "${wine_git_date_roffset}" )
	local __wine_forward_date_limit=$( get_date_offset "${__wine_commit_date}" "${wine_git_date_foffset}" )
	get_sieved_git_commit_log "${wine_git_dir}" "${__wine_reverse_date_limit}" "${__wine_forward_date_limit}" "__wine_git_log_array"
	local commit_total=${#__wine_git_log_array[@]}
	local pre_index=-1
	local post_index=${commit_total}
	local index
	for index in "${!__wine_git_log_array[@]}"; do
		[[ "x${!__wine_commit_retvar}" == "x${__wine_git_log_array[index]:0:40}" ]] && break
	done
	(( ($? == 0) && ( pre_index=post_index=index ) ))
	while (( (0<=pre_index) || (post_index<commit_total) )); do
		# Go backwards
		if (( pre_index >= 0 )); then
			local pre_commit_target_child="${__wine_git_log_array[pre_index]:41:40}"
			while (( --pre_index >= 0 )); do
				[[ "x${pre_commit_target_child}" == "x${__wine_git_log_array[pre_index]:0:40}" ]] && break
			done
			if (( pre_index >= 0 )); then
				local target_wine_commit="${__wine_git_log_array[pre_index]:0:40}"
				local __wine_commit_diff=$(( pre_index - index ))
				local target_wine_staging_commit
				walk_wine_staging_git_tree "${wine_staging_git_dir}" "${wine_git_dir}" "${target_wine_commit}" "target_wine_staging_commit" \
					&& break
			fi
		fi
		# Go forwards
		if (( post_index < commit_total )); then
			local post_commit_target_parent="${__wine_git_log_array[post_index]:0:40}"
			while (( ++post_index < commit_total )); do
				[[ "x${post_commit_target_parent}" == "x${__wine_git_log_array[post_index]:41:40}" ]] && break
			done
			if (( post_index < commit_total )); then
				local target_wine_commit="${__wine_git_log_array[post_index]:0:40}"
				local __wine_commit_diff=$(( post_index - index ))
				local target_wine_staging_commit
				walk_wine_staging_git_tree "${wine_staging_git_dir}" "${wine_git_dir}"  "${target_wine_commit}" "target_wine_staging_commit" \
					&& break
			fi
		fi
	done
	unset -v __wine_git_log_array
	[[ ! -z "${git_dir}" ]] && { popd || die; }
	[[ -z "${target_wine_staging_commit}" ]] && return 1
	eval $__wine_commit_retvar="'${target_wine_commit}'"
	eval $__wine_staging_commit_retvar="'${target_wine_staging_commit}'"
	[[ -z "{$__wine_commit_diff_retvar}" ]] || eval $__wine_commit_diff_retvar="'${__wine_commit_diff}'"
}

# display_closest_wine_commit_message()
# 1>  : Target Wine git commit (SHA-1) hash
# 2>  : Target Wine-Staging git commit (SHA-1) hash
# 3>  : Wine git tree commit offset
display_closest_wine_commit_message()
{
	((${#}==3)) || die "Invalid argument count (3)"
	local	__target_wine_commit="${1}"
	local	__target_wine_staging_commit="${2}"
	local	__wine_commit_diff="${3}"

	[[ "${__target_wine_commit}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (1): invalid Wine SHA-1 git commit \"${__target_wine_commit}\""
	[[ "${__target_wine_staging_commit}" =~ ${SHA1_REGEXP} ]] \
			|| die "Parameter (2): invalid Wine-Staging SHA-1 git commit \"${__target_wine_staging_commit}\""
	if (( __wine_commit_diff < 0 )); then
		__wine_commit_diff=$((-__wine_commit_diff))
		local diff_message="offset ${__wine_commit_diff} commits back"
	elif (( __wine_commit_diff > 0 )); then
		local diff_message="offset ${__wine_commit_diff} commits foward"
	else
		local diff_message="no offset"
	fi
	(( __wine_commit_diff == 1 )) && diff_message="${diff_message/commits /commit }"

	eerror "Try rebuilding this package using the closest supported Wine commit (${diff_message}):"
	eerror "   EGIT_WINE_COMMIT=\"${__target_wine_commit}\" emerge -v =${CATEGORY}/${P}  # build against Wine commit"
	eerror "... or:"
	eerror "EGIT_STAGING_COMMIT=\"${__target_wine_staging_commit}\" emerge -v =${CATEGORY}/${P}  # build against Wine-Staging commit"
	eerror
}
