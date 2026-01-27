#!/bin/bash
#
# Copyright 2026 Lekhtin A.V. (Che Miass) All rights reserved.
# SPDX-License-Identifier: MIT
#
# Migrate remote gitlab repository to gitea
#
# note: Gitlab groups is migrating to $GITEA_USERNAME 
#

GITLAB_URL="192.168.1.29"
GITLAB_USERNAME=lav
GITLAB_TOKEN=glpat-OjityEFcCJpjdNZojb_MdW86MQp1OjIH.01.0w17lr7ku
GITLAB_ORGANISATION=

GITEA_URL=gitea:3000
GITEA_USERNAME=lav  # maintainer for receiving the repos from gitlab group
GITEA_TOKEN=8727760d8992afbfb10478c833a1a3548f0821b5

REPOS_ID=()
REPOS_NAME=()
REPOS_DESCRIPTION=()
REPOS_OWNER=()
REPOS_PATH=()
REPOS_WEBPATH=()
REPOS_GROUP=()

function check_gitlab_access()
{
    printf "*** %-25s ... " "check connection"
    cmd="curl -s --header \"PRIVATE-TOKEN: $GITLAB_TOKEN\" \"http://${GITLAB_URL}/api/v4/personal_access_tokens\""
    #echo -e "\n$cmd"
    resp=$(eval $cmd)
    if [ -z "$resp" ]; then
        printf "error for $GITLAB_URL\n\n"
        exit 1
    fi

    STR=$(echo $resp | jq -r '.message' 2</dev/null)
    if [[ "$STR" =~ "401" ]]; then
        printf "User $GITLAB_USERNAME not authorized in gitlab (or token incorrect)\n\n"
        exit 1
    fi
    echo "OK"
}

function get_users()
{
    # outdated now! unused.

    TMPFILE="/tmp/users"
    rm -f $TMPFILE &> /dev/null

    printf "*** %-25s ... " "check users"
    cmd="curl -s --header \"PRIVATE-TOKEN: $GITLAB_TOKEN\" \
        \"http://$GITLAB_URL/api/v4/users?page=1&per_page=1000\" > $TMPFILE"
    #echo -e "\n$cmd"
    eval $cmd
    if [ ! -r "$TMPFILE" ]; then
        printf "access error for $GITLAB_URL\n\n"
        exit 1
    fi

    USERS=$(jq -r '.[].username' $TMPFILE | grep -v GitLab | sort --ignore-case)
    if [ -z "$USERS" ]; then
        printf "not found\n\n"
        exit 1
    fi
    echo "OK"

    #printf "\n*** found users:\n"
    NUM=1
    for user in $USERS; do
        printf "%2d: %s\n" $NUM "$user"
        NUM=$((NUM+1))
    done
}

function get_repo_groups()
{
    TMPFILE="/tmp/group"
    rm -f $TMPFILE &> /dev/null

    printf "*** %-25s ... " "check group"
#    cmd="curl -s --header \"PRIVATE-TOKEN: $GITLAB_TOKEN\" \
#    \"http://$GITLAB_URL/api/v4/groups?page=1&per_page=1000\" | \
#    jq -r '.[].name'"
    cmd="curl -s --header \"PRIVATE-TOKEN: $GITLAB_TOKEN\" \
        \"http://$GITLAB_URL/api/v4/groups?page=1&per_page=1000\" > $TMPFILE"
    #echo -e "\n$cmd"
    eval $cmd
    if [ ! -r "$TMPFILE" ]; then
        printf "access error for $GITLAB_URL\n\n"
        exit 1
    fi

    REPO_GROUPS="$(jq -r '.[].name' $TMPFILE)"
    if [ -z "$REPO_GROUPS" ]; then
        printf "not found\n\n"
        return
    fi
    echo "OK"

    #printf "\n*** found repo groups:\n"
    NUM=1
    for group in $REPO_GROUPS; do
        printf "%2d: %s\n" $NUM "$group"
        NUM=$((NUM+1))
    done
}

function create_groups()
{
    # unused now!

    printf "*** %-25s ... " "create Gitea group"
    for group in ${REPOS_GROUP[*]}; do
        printf "    %-25s ... " "$group"
        cmd="curl -s --header \"PRIVATE-TOKEN: $GITLAB_TOKEN\" \
        \"http://$GITLAB_URL/api/v4/orgs/$group/repos\" \
        -H \"accept: application/json\" \
        -H \"Content-Type: application/json\" \
        -d '""{\"name\": \"$group\", \"private\": false}""'"

        RES="$(eval $cmd)"
        RC=$?

        if [[ "$RES" =~ "message" ]]; then
            echo "FAILED (1)"
            echo -e "$RES"
            return 1
        elif [ $RC -ne 0 ]; then
            echo "FAILED (2)"
        else
            echo "OK"
        fi
    done

    # -H \"Authorization: token YOUR_API_TOKEN\"
}

function get_repos()
{
    TMPFILE="/tmp/repos"
    rm -f $TMPFILE &> /dev/null

    printf "*** %-25s\n" "get repo list"
    cmd="curl -s --header \"PRIVATE-TOKEN: $GITLAB_TOKEN\" \
    \"http://$GITLAB_URL/api/v4/projects?page=1&per_page=1000\" | \
    tr -d '\000-\037' > $TMPFILE"
    #echo -e "\n$cmd"
    eval $cmd
    if [ ! -r "$TMPFILE" ]; then
        printf "access error for $GITLAB_URL\n\n"
        exit 1
    fi

    printf "    %-25s ... " "get id"
    id_array=$(jq -r '.[].id' $TMPFILE | sort -g)
    for id in $id_array; do
        REPOS_ID+=($id)
    done
    echo "OK"

    printf "    %-25s ... " "get name"
    for id in ${REPOS_ID[*]}; do
        cmd="jq -r '.[] | select(.id == ${id}) | .name' $TMPFILE"
        res=$(eval $cmd | sed 's/[ -]/_/g;s/___/_/g' | konwert utf8-iso8)
        REPOS_NAME+=("$res")
    done
    echo "OK"

    printf "    %-25s ... " "get description"
    for id in ${REPOS_ID[*]}; do
        cmd="jq -r '.[] | select(.id == ${id}) | .description' $TMPFILE"
        res=$(eval $cmd | tr -s "\r\n" "\n") # | konwert utf8-iso8
        descr="$res"
        [ -z "$descr" ] && descr="-";
        [[ "$descr" =~ "null" ]] && descr="-";
        REPOS_DESCRIPTION+=("$descr")
    done
    echo "OK"

    printf "    %-25s ... " "get owner"
    for id in ${REPOS_ID[*]}; do
        cmd="jq -r '.[] | select(.id == ${id}) | .owner.username' $TMPFILE"
        res=$(eval $cmd)
        owner="$res"
        [[ "$owner" =~ "null" ]] && owner="";
        REPOS_OWNER+=("$owner")
    done
    echo "OK"

    printf "    %-25s ... " "get group"
    for idx in ${!REPOS_ID[*]}; do
        res=""
        if [ -z "${REPOS_OWNER[$idx]}" ]; then
            cmd="jq -r '.[] | select(.id == ${REPOS_ID[$idx]}) | .namespace.name' $TMPFILE"
            REPOS_OWNER[$idx]=$GITEA_USERNAME
            res=$(eval $cmd | sed 's/[ -]/_/g;s/___/_/g' | konwert utf8-iso8)
        fi
        REPOS_GROUP+=("$res")
    done
    echo "OK"

    printf "    %-25s ... " "get path"
    for id in ${REPOS_ID[*]}; do
        cmd="jq -r '.[] | select(.id == ${id}) | .path_with_namespace' $TMPFILE"
        res=$(eval $cmd)
        REPOS_PATH+=("$res")
    done
    echo "OK"

    printf "    %-25s ... " "get webpath"
    for id in ${REPOS_ID[*]}; do
        cmd="jq -r '.[] | select(.id == ${id}) | .web_url' $TMPFILE"
        res=$(eval $cmd)
        REPOS_WEBPATH+=("$res")
    done
    echo "OK"

    NUM=1
    printf "\n*** found repo:\n"
    for idx in ${!REPOS_ID[*]}; do
        printf "%2d name:%-20s own:%-8s group:%-8s path:%-30s desc:%s\n" $NUM \
            "${REPOS_NAME[$idx]:0:20}"\
            "${REPOS_OWNER[$idx]:0:8}"\
            "${REPOS_GROUP[$idx]:0:8}" \
            "${REPOS_PATH[$idx]:0:30}" \
            "$(echo ${REPOS_DESCRIPTION[$idx]:0:30} | tr -d '\n')"
        NUM=$((NUM+1))
    done
    #rm -f $TMPFILE &>/dev/null
}


function import_to_gitea()
{
    printf "*** %-25s ... \n" "import"
    for idx in ${!REPOS_ID[*]}; do
        printf "    %2d: import %-40s ... " $idx "${REPOS_PATH[$idx]}"

        cmd="curl -i -s -X POST http://$GITEA_URL/api/v1/repos/migrate \
        -u $GITEA_USERNAME:$GITEA_TOKEN \
        -H \"accept: application/json\" \
        -H \"Content-Type: application/json; charset=utf-8\" \
        --data-raw '""{ \
 \"clone_addr\":   \"${REPOS_WEBPATH[$idx]}\",  \
 \"repo_name\":    \"${REPOS_NAME[$idx]}\",     \
 \"auth_username\":\"$GITLAB_USERNAME\",        \
 \"auth_token\":   \"$GITLAB_TOKEN\",           \
 \"private\":       false, \
 \"mirror\":        false, \
 \"issues\":        true,  \
 \"pull_requests\": false, \
 \"wiki\":          false, \
 \"labels\":        true,  \
 \"milestones\":    true,  \
 \"lfs\":           true,  \
 \"empty\":         true,  \
 \"service\": \"gitlab\"   \
 }""'"

# below does not work :(  - requries token for each userspace - it is not usefull :(
# \"repo_owner\":   \"${REPOS_OWNER[$idx]}\",    \
# \"new_owner\":    \"${REPOS_OWNER[$idx]}\",    \
 
        #echo $cmd
        RES="$(eval $cmd)"
        RC=$?

        if [[ "$RES" =~ "message" ]]; then
            echo "FAILED (1)"
            echo -e "$RES"
            return 1
        elif [ $RC -ne 0 ]; then
            echo "FAILED (2)"
            return 1
        else
            echo "OK"
        fi
    done
}


check_gitlab_access
get_repo_groups
get_repos
import_to_gitea
