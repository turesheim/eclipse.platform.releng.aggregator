#!/usr/bin/env bash

# Utility to trigger the promotion of build. This utility just creates
# a file to be executed by cron job. The actual promotion is done by files
# in sdk directory of build machine. This "cron job approach" is required since
# a different user id must promote things to "downloads". The promotion scripts
# also trigger the unit tests on Hudson.

function usage ()
{
  printf "\n\n\t%s\n" "promote-build.sh (BUILD_KIND) if none specified, CBI assumed"
}

BUILD_KIND=$1
if [[ -z "$BUILD_KIND" ]]
then
  BUILD_KIND=CBI
fi

case $BUILD_KIND in

  'CBI' )
    echo "Promote Build from CBI"
    # always assume true, for now, until debugged
    # testbuildonly=true;

    ;;
  *) echo "ERROR: Invalid or missing argument to $(basename $0)";
    usage;
    exit 1;
    ;;
esac

if [[ -z ${SCRIPT_PATH} ]]
then
  SCRIPT_PATH=${PWD}
fi

source $SCRIPT_PATH/build-functions.shsource

source "$2" 2>/dev/null

# The 'workLocation' provides a handy central place to have the
# promote script, and log results. ASSUMING this works for all
# types of builds, etc (which is the goal for the sdk promotions).
workLocation=/shared/eclipse/sdk/promotion

# the cron job must know about and use this same
# location to look for its promotions scripts. (i.e. implicite tight coupling)
promoteScriptLocationEclipse=$workLocation/queue

# directory should normally exist -- best to create first, with committer's ID --
# but in case not
mkdir -p "${promoteScriptLocationEclipse}"
#env > env.txt

if [[ -z ${STREAM} || -z ${BUILD_ID} ]]
then
  echo "ERROR: This script requires STREAM and BUILD_ID"
  exit 1
fi

scriptName=promote-${STREAM}-${BUILD_ID}.sh
if [[ "${testbuildonly}" == "true" ]]
then
  # allows the "test" creation of promotion script, but, not have it "seen" be cron job
  scriptName=TEST-$scriptName
fi

# if EBUILDER_HASH is not defined, assume master, so order of following parameters are maintained.
if [[ -z "${EBUILDER_HASH}" ]]
then
  EBUILDER_HASH=master
fi

# Here is content of promtion script:
ptimestamp=$( date +%Y%m%d%H%M )
echo "#!/usr/bin/env bash" >  ${promoteScriptLocationEclipse}/${scriptName}
echo "# promotion script created at $ptimestamp" >>  ${promoteScriptLocationEclipse}/${scriptName}
# TODO: changed "syncDropLocation" to handle a third parameter (BUILD_KIND)
# And now a fourth ... eBuilder HASHTAG,so won't always have to assume master, and
# so the tests can get their own copy.
# and now a fifth, so we can 'source' all relevent variables ... in particular, we want
# to see if BUILD_FAILED is defined.
echo "$workLocation/syncDropLocation.sh $STREAM $BUILD_ID $BUILD_KIND $EBUILDER_HASH $BUILD_ENV_FILE" >> ${promoteScriptLocationEclipse}/${scriptName}

# we restrict "others" rights for a bit more security or safety from accidents
chmod -v ug=rwx,o-rwx ${promoteScriptLocationEclipse}/${scriptName}

# we do not promote equinox, if BUILD_FAILED since no need.
if [[ -z "${BUILD_FAILED}" ]]
then

  # The 'workLocation' provides a handy central place to have the
  # promote script, and log results. ASSUMING this works for all
  # types of builds, etc (which is the goal for the sdk promotions).
  workLocationEquinox=/shared/eclipse/equinox/promotion

  # the cron job must know about and use this same
  # location to look for its promotions scripts. (i.e. tight coupling)
  promoteScriptLocationEquinox=${workLocationEquinox}/queue

  # Directory should normally exist -- best to create with committer's ID before hand,
  # but in case not.
  mkdir -p "${promoteScriptLocationEquinox}"

  equinoxPostingDirectory="$BUILD_ROOT/siteDir/equinox/drops"
  eqFromDir=${equinoxPostingDirectory}/${buildId}
  eqToDir="/home/data/httpd/download.eclipse.org/equinox/drops/"

  # Note: for proper mirroring at Eclipse, we probably do not want/need to
  # maintain "times" on build machine, but let them take times at time of copying.
  # If it turns out to be important to maintain times (such as ran more than once,
  # to pick up a "more" output, such as test results, then add -t to rsync
  # Similarly, if download server is set up right, it will end up with the
  # correct permissions, but if not, we may need to set some permissions first,
  # then use -p on rsync

  # Here is content of promtion script (note, use same ptimestamp created above):
  echo "#!/usr/bin/env bash" >  ${promoteScriptLocationEquinox}/${scriptName}
  echo "# promotion script created at $ptimestamp" >  ${promoteScriptLocationEquinox}/${scriptName}
  echo "rsync --times --omit-dir-times --recursive \"${eqFromDir}\" \"${eqToDir}\"" >> ${promoteScriptLocationEquinox}/${scriptName}

  # we restrict "others" rights for a bit more security or safety from accidents
  chmod -v ug=rwx,o-rwx ${promoteScriptLocationEquinox}/${scriptName}

else
  echo "Did not create promote script for equinox since BUILD_FAILED"
fi

echo "normal exit from promote phase of $(basename $0)"

exit 0
