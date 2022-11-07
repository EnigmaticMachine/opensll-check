#!/usr/bin/env bash

# DEFAULTS
DIRS="/usr /lib64 /lib /opt"
EXPRESSION="3.0($|.[0-6])"
LOG_NAME="openssl_check.csv"

function usage {
    printf "Usage: %s [options]\n" "$(basename $0)"
    printf "Description:
    Check for occurence of libcrypto.so library matching version from expression parameter
    and if lsof utility is available, check if library is used by some process\n"
    printf "Options:
    -h              Show this help
    -d DIRS         Directories separated by whitespace to include in search for libcrypto.so (Default: \"%s\")
    -e EXPRESSION   ERE Expression to be used in grep when matching version of libcrypto.so (Default: \"%s\")
    -l LOG_NAME     Log name where results in CSV-like output are written (Default: \"%s\")\n" "${DIRS}" "${EXPRESSION}" "${LOG_NAME}"
}

while getopts "hd:e:l:" option; do
    case "${option}" in
        h)
            usage
            exit 0
            ;;
        d)
            DIRS="${OPTARG}"
            ;;
        e)
            EXPRESSION="${OPTARG}"
            ;;
        l)
            LOG_NAME="${OPTARG}"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

OVER="\\r\\033[K"

function log {
    if [[ -n "${LOG_NAME}" ]]; then
        echo "${1}" >> "${LOG_NAME}"
    fi
}

if [[ $(whoami) != "root" ]]; then
    printf "WARNING | Not executed as root, result may not be complete\n"
fi

if ! which lsof &>/dev/null; then
    printf "WARNING | lsof bin not found\n"
    has_lsof=True
fi

if [[ -n "${LOG_NAME}" ]]; then
    :> "${LOG_NAME}"
    log '"Library path";"lsof result"'
fi

printf "INFO    | Looking for libcrypto.so matching expression \"%s\" in following folders \"%s\"\n" "${EXPRESSION}" "${DIRS}"

for i in $(find ${DIRS} -type f -name "libcrypto.so*" | grep -E "${EXPRESSION}"); do
    if [[ -z $has_lsof ]]; then
        used=$(lsof ${i} 2>/dev/null)
        if [[ -z ${used} ]]; then
            printf "INFO    | Matching library located at: %s\n" "${i}"
            log "\"${i}\";\"\""
        else
            printf "ERROR   | Matching and opened/used library located at: %s\n" "${i}"
            c=0
            while IFS= read -r line; do
                if [[ c -eq 6 ]]; then # print only first 5 occurences (including header)
                    printf "          ...\n"
                    log "\"\";\"...\""
                    break
                elif [[ c -eq 0 ]]; then # don't log header from lsof
                    printf "          ${line}\n"
                elif [[ c -eq 1 ]]; then
                    printf "          ${line}\n"
                    log "\"${i}\";\"${line}\""
                else
                    printf "          ${line}\n"
                    log "\"\";\"${line}\""
                fi
                ((c=c+1))
            done <<< "${used}"
        fi
    else
        printf "\n"
        log "\"${i}\";\"\""
    fi
done

exit 0
