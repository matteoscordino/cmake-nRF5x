#!/bin/bash
# this file (revision_gen.template.sh) is the template for the script to generate the revision header automatically from git
#
# the @VAR@ variables in here get replaced by cmake according to the build configuration (a bit like running ./configure
# from autotools) to generate (in the build directoru) the final script that is called to create revision.h

source "@DIR_OF_nRF5x_CMAKE@/get_git_rev.inc.sh"

FILENAME="revision.h"
OUT="@CMAKE_CURRENT_SOURCE_DIR@/${FILENAME}"

echo "writing to $(pwd)/${OUT}"
echo "GIT_LATEST_TAG=${GIT_LATEST_TAG}"
echo "GIT_BRANCH=${GIT_BRANCH}"
echo "GIT_HASH=${GIT_HASH}"
echo "GIT_DIRTY=${GIT_DIRTY}"

echo "#ifndef _REVISION_H" > ${OUT}
echo "#define _REVISION_H" >> ${OUT}

echo "" >> ${OUT}

echo "#define GIT_LATEST_TAG \"${GIT_LATEST_TAG}\"" >> ${OUT}
echo "#define GIT_BRANCH \"${GIT_BRANCH}\"" >> ${OUT}
echo "#define GIT_HASH \"${GIT_HASH}\"" >> ${OUT}
echo "#define GIT_DIRTY \"${GIT_DIRTY}\"" >> ${OUT}
echo "#define GIT_DIRTY_BOOL ${GIT_DIRTY}" >> ${OUT}


echo "" >> ${OUT}

echo "#endif // _REVISION_H" >> ${OUT}
