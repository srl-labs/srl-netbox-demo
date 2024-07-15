#!/bin/bash
nb_runscript () {
  (
    set +x
    set -euo pipefail
    TOKEN="c4cd2e9bf74869feb061eba14b090b4811353d9c"
    NETBOX_API_URL="http://netbox:8000/api"
    RETURNDATA=$(mktemp)
    TRACE=$(mktemp)
    SCRIPT=${1}
    SILENT=0
    VERBOSE=0
    COMMIT="true"
    DEBUG=0
    shift
    while [ $# -gt 0 ]; do
      case ${1} in
        -f|--file)
        FILE="${2}"
        shift
        shift
        if [ ! -e "${FILE}" ]; then
          echo "${FILE} does not exist!"
          exit 1
        fi
        ;;
        -d|--data)
        echo "${2}" | jq -c . >/dev/null 2>&1 || (echo "Data did not parse as JSON!"; exit 1)
        DATA="$(echo "${2}" | jq -c .)"
        shift
        shift
        ;;
        -v|--verbose)
        VERBOSE=1
        shift
        ;;
        -s|--silent)
        SILENT=1
        shift
        ;;
        --dry-run)
        COMMIT="false"
        shift
        ;;
        --debug)
        DEBUG=1
        shift
        ;;
        *)
        echo "Unknown option ${1}"
        exit 1
        ;;
      esac
    done
    if [ ${DEBUG} -eq 1 ]; then
      set -x
    fi
    if [ ${VERBOSE} -eq 0 -a ${SILENT} -eq 0 ]; then
      if [ "${COMMIT}" == "false" ]; then
        echo -n "Running script ${SCRIPT} in DRY-RUN: "
      else
        echo -n "Running script ${SCRIPT}: "
      fi
    fi
    curl -v -s -X POST -H "Authorization: Token ${TOKEN}" -H "Accept: application/json" -F "data=${DATA:-{\}}" -F "commit=${COMMIT}" ${FILE:+-F yamlfile=@}${FILE:-} "${NETBOX_API_URL}/extras/scripts/${SCRIPT}/" 2>"${TRACE}" | jq . >"${RETURNDATA}"
    JOBURL=$(cat "${RETURNDATA}" | jq -r .result.url)
    if [ ${VERBOSE} -eq 1 -a ${SILENT} -eq 0 ]; then
      grep "^>" "${TRACE}" | sed -e '/^>\s*$/d'
      if [ "${DATA:-}" != "" ]; then
        jq --null-input "${DATA}" | sed -e 's/^/>    /'
      fi
      if [ "${FILE:-}" != "" ]; then
        sed -e 's/^/>    /' "${FILE}"
      fi
      echo ""
      grep "^<" "${TRACE}" | sed -e '/^<\s*$/d'
      # sed -e 's/^/<    /' "${RETURNDATA}"
      echo ""
    fi
    while true; do
      curl -v -s -H "Authorization: Token ${TOKEN}" -H "Accept: application/json" "${JOBURL}" 2>"${TRACE}" | jq . >"${RETURNDATA}"
      JOBSTATUS=$(cat "${RETURNDATA}" | jq -r .status.value)
      case ${JOBSTATUS:-unknown} in
        pending|running)
        if [ ${VERBOSE} -eq 0 -a ${SILENT} -eq 0 ]; then
          echo -n .
        fi
        ;;
        errored)
        if [ ${VERBOSE} -eq 0 -a ${SILENT} -eq 0 ]; then
          echo ""
          echo "Error occured!"
        fi
        if [ ${VERBOSE} -eq 1 -a ${SILENT} -eq 0 ]; then
          grep "^>" "${TRACE}" | sed -e '/^>\s*$/d'
          echo ""
          grep "^<" "${TRACE}" | sed -e '/^<\s*$/d'
          sed -e 's/^/<    /' "${RETURNDATA}"
          echo ""
        fi
        exit 1
        ;;
        completed)
        break
        ;;
        *)
        echo "Unknown status ${JOBSTATUS}"
        exit 1
        ;;
      esac
      sleep .5
    done
    if [ ${VERBOSE} -eq 1 -a ${SILENT} -eq 0 ]; then
      grep "^>" "${TRACE}" | sed -e '/^>\s*$/d'
      echo ""
      grep "^<" "${TRACE}" | sed -e '/^<\s*$/d'
      sed -e 's/^/<    /' "${RETURNDATA}"
      echo ""
    fi
    if [ ${VERBOSE} -eq 0 -a ${SILENT} -eq 0 ]; then
      echo ""
      echo "Done!"
    fi
    rm -f "${TRACE}"
    rm -f "${RETURNDATA}"
  )
}
