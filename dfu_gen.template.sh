#!/bin/bash
# this file (dfu_gen.template.sh) is the template for the script to generate the DFU zip
#
# the @VAR@ variables in here get replaced by cmake according to the build configuration (a bit like running ./configure
# from autotools) to generate (in the build directoru) the final script that is called to create the DFU zip

source "@DIR_OF_nRF5x_CMAKE@/get_git_rev.inc.sh"

APP_VERSION=$(get_tag_as_integer)
APP_VERSION_WITH_DIRTY=${APP_VERSION}
if [ "${GIT_DIRTY}" = "true" ]; then
  APP_VERSION_WITH_DIRTY=${APP_VERSION_WITH_DIRTY}"-dirty"
fi

echo -e "\nget_git_rev: decimal app verion: ${APP_VERSION}"

@NRFUTIL@ pkg generate --hw-version @SHORT_HW_VERSION@ --application-version "${APP_VERSION}" --application @EXE_NAME@.hex --sd-req @SD_FWID@ --key-file @DFU_SIGNING_KEY@ @DFU_PKG_DEST_PREFIX@"${APP_VERSION_WITH_DIRTY}".zip