#!/bin/bash
# heavily inspired by ttionya/vaultwarden-backup

. /app/includes.sh
ERROR_LIST=()

########################################
# Print a error message
# Arguments:
#     reason message
#     details put into log
########################################
function error() {
    color red "$1"
    ERROR_LIST+=("$(print_date): Error: $2 (Reason: $1)")
}

########################################
# Send result email report
# Arguments:
#     None
########################################
function result_mail() {
    if [[ ${#ERROR_LIST[@]} == 0 ]]; then
        send_mail_content "TRUE" "Repo-Backup passed at $(print_date)."
    else
        send_mail_content "FALSE" "Repo-Backup failed at $(print_date).\nLogs:\n$(printf "%s\n" "${ERROR_LIST[@]}")"
    fi
}

########################################
# Remove backup folder
# Arguments:
#     None
########################################
function clear_dir() {
    rm -rf "${BACKUP_DIR}"
}

########################################
# Initialize this backup run - set global variables
# Arguments:
#     Basename e.g. svn
#     Respository name
########################################
function backup_init() {
    NOW="$(date +"${BACKUP_FILE_DATE_FORMAT}")"
    # backup zip file
    BACKUP_FILE_ZIP="${BACKUP_DIR}/${1}_${2}.${NOW}.${ZIP_TYPE}"
    UPLOAD_FILE="invalid.path"
}

########################################
# Send mail.
# Arguments:
#     svn list index
########################################
function backup_svn() {
    local RETVAL
    mkdir -p "${BACKUP_DIR}"

    svn export --force --non-interactive --trust-server-cert --no-auth-cache ${SVN_ARGS_LIST[$1]} "${BACKUP_DIR}"
    RETVAL=$?
    if [[ ${RETVAL} != 0 ]]; then
        error "svn export error code ${RETVAL}" "REPO-NAME: \"${SVN_NAME_LIST[$1]}\", \"${SVN_ARGS_INFO_LIST[$1]}\""
    else
        color green "svn export succeeded"
    fi

    color blue "svn repo contents"

    ls -lah "${BACKUP_DIR}"
    return ${RETVAL}
}

########################################
# Zip backup contents
# Arguments:
#     none
########################################
function backup_package() {
    if [[ "${ZIP_ENABLE}" == "TRUE" ]]; then
        color blue "package backup file"

        UPLOAD_FILE="${BACKUP_FILE_ZIP}"

        if [[ "${ZIP_TYPE}" == "zip" ]]; then
            7z a -tzip -mx=9 -p"${ZIP_PASSWORD}" "${BACKUP_FILE_ZIP}" "${BACKUP_DIR}"/*
            RETVAL=$?
        else
            7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhe=on -p"${ZIP_PASSWORD}" "${BACKUP_FILE_ZIP}" "${BACKUP_DIR}"/*
            RETVAL=$?
        fi
        if [[ ${RETVAL} != 0 ]]; then
            error "7z error code ${RETVAL}" "7zip failed"
        fi

        ls -lah "${BACKUP_DIR}"

        color blue "display backup ${ZIP_TYPE} file list"

        7z l -p"${ZIP_PASSWORD}" "${BACKUP_FILE_ZIP}"
    else
        color yellow "skip package backup files"

        UPLOAD_FILE="${BACKUP_DIR}"
    fi
}

########################################
# upload backup contents
# Arguments:
#     none
########################################
function upload() {
    local RETVAL
    # upload file not exist
    if [[ ! -e "${UPLOAD_FILE}" ]]; then
        error "upload file not found" "upload skipped"

        return 1
    fi

    # upload
    local HAS_ERROR="FALSE"

    for RCLONE_REMOTE_X in "${RCLONE_REMOTE_LIST[@]}"
    do
        color blue "upload backup file to storage system $(color yellow "[${RCLONE_REMOTE_X}]")"

        rclone ${RCLONE_GLOBAL_FLAG} copy "${UPLOAD_FILE}" "${RCLONE_REMOTE_X}"
        RETVAL=$?
        if [[ ${RETVAL} != 0 ]]; then
            error "rclone error code ${RETVAL}" "upload failed \"${UPLOAD_FILE}\" \"${RCLONE_REMOTE_X}\""

            HAS_ERROR="TRUE"
        fi
    done

    if [[ "${HAS_ERROR}" == "TRUE" ]]; then
        return 1
    fi
}

########################################
# delete old files
# Arguments:
#     none
########################################
function clear_history() {
    local RETVAL
    if [[ "${BACKUP_KEEP_DAYS}" -gt 0 ]]; then
        for RCLONE_REMOTE_X in "${RCLONE_REMOTE_LIST[@]}"
        do
            color blue "delete ${BACKUP_KEEP_DAYS} days ago backup files $(color yellow "[${RCLONE_REMOTE_X}]")"

            mapfile -t RCLONE_DELETE_LIST < <(rclone ${RCLONE_GLOBAL_FLAG} lsf "${RCLONE_REMOTE_X}" --min-age "${BACKUP_KEEP_DAYS}d")

            for RCLONE_DELETE_FILE in "${RCLONE_DELETE_LIST[@]}"
            do
                color yellow "deleting \"${RCLONE_DELETE_FILE}\""

                rclone ${RCLONE_GLOBAL_FLAG} delete "${RCLONE_REMOTE_X}/${RCLONE_DELETE_FILE}"
                RETVAL=$?
                if [[ ${RETVAL} != 0 ]]; then
                    error "rclone error code ${RETVAL}" "delete \"${RCLONE_DELETE_FILE}\" failed"
                fi
            done
        done
    fi
}

color blue "running the backup program at $(print_date)"

init_env
check_rclone_connection

for i in "${!SVN_NAME_LIST[@]}";
do
    color blue "- backup SVN-REPO: \"${SVN_NAME_LIST[$i]}\" start: $(print_date)"
    clear_dir
    backup_init "svn" "${SVN_NAME_LIST[$i]}"
    backup_svn ${i}
    if [[ $? == 0 ]]; then
        backup_package
        upload
    fi
    clear_dir
    color blue "- backup SVN-REPO: \"${SVN_NAME_LIST[$i]}\" end: $(print_date)"
done

clear_history

result_mail
send_ping

color none ""
