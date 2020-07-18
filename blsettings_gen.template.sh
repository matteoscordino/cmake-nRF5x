#!/bin/bash
# this file (blsettins_gen.template.sh) is the template for the script to generate the bootloader settings page.
#
# the @VAR@ variables in here get replaced by cmake according to the build configuration (a bit like running ./configure
# from autotools) to generate (in the build directoru) the final script that is called to create the settings page hex

source "@DIR_OF_nRF5x_CMAKE@/get_git_rev.inc.sh"

APP_VERSION=$(get_tag_as_integer)

echo -e "\nget_git_rev: decimal app verion: ${APP_VERSION}"

@NRFUTIL@ settings generate --family $(echo @NRF_TARGET@ | tr [a-z] [A-Z]) --application @EXE_NAME@.hex --application-version "${APP_VERSION}" --bootloader-version 1 --bl-settings-version 2 settings.hex
@MERGEHEX@ -m settings.hex @EXE_NAME@.hex -o @EXE_NAME@_with_bl_settings.hex