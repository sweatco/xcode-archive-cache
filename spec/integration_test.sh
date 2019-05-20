#! /bin/bash
set -x
set -o pipefail

check_for_positive_result() {
  if [ $? != 0 ]; then
    echo "\"$1\"" failed
    exit 1
  else
    echo "\"$1\"" succeeded
  fi
}

check_for_negative_result() {
  if [ $? == 0 ]; then
    echo "\"$1\"" failed
    exit 1
  else
    echo "\"$1\"" succeeded
  fi
}

TEST_PROJECT_LOCATION="fixtures/test_project/Test"
TEST_DESTINATION="platform=iOS Simulator,name=iPhone 7,OS=latest"

perform_full_clean() {
  git clean -xdf . && git checkout HEAD -- .
  check_for_positive_result "Full clean"
}

clean_but_leave_build_cache() {
  git clean -xdf -e "build_cache" . && git checkout HEAD -- .
  check_for_positive_result "Clean leaving build cache"
}

make_filename_list_enumerable() {
  echo "$1" | tr "|" " "
}

perform_test() {
  pod install
  check_for_positive_result "Install pods"

  xcode-archive-cache inject --destination="$TEST_DESTINATION" --action=build --log-level=verbose | tee cache.log
  check_for_positive_result "Build and cache dependencies"

  # check what was rebuilt
  #
  FRAMEWORKS=$(make_filename_list_enumerable "$1")
  for FRAMEWORK_NAME in $FRAMEWORKS; do
    grep -q "Touching $FRAMEWORK_NAME" cache.log
    check_for_positive_result "Rebuild check for $FRAMEWORK_NAME"
  done

  xcodebuild -workspace Test.xcworkspace -scheme Test -destination "$TEST_DESTINATION" -derivedDataPath build test | xcpretty | tee xcodebuild.log
  check_for_positive_result "Test app"

  # check that none of cached dependencies
  # were rebuilt during app build
  #
  FRAMEWORKS=$(make_filename_list_enumerable "$2")
  for FRAMEWORK_NAME in $FRAMEWORKS; do
    grep -q "Touching $FRAMEWORK_NAME" xcodebuild.log
    check_for_negative_result "No-extra-rebuild check for $FRAMEWORK_NAME"
  done
}

update_single_pod() {
  sed -i.bak "s+2.5.3+2.5.4+g" Podfile
  check_for_positive_result "Update single pod"
}

cd $TEST_PROJECT_LOCATION

ALL_FRAMEWORKS="SDCAutoLayout.framework|RBBAnimation.framework|MRProgress.framework|SDCAlertView.framework|Pods_Test.framework"
perform_full_clean && perform_test $ALL_FRAMEWORKS $ALL_FRAMEWORKS

# update single pod, expecting it to be rebuilt
#
clean_but_leave_build_cache && update_single_pod

FRAMEWORKS_EXPECTED_TO_BE_REBUILT="SDCAutoLayout.framework|SDCAlertView.framework|Pods_Test.framework"
perform_test $FRAMEWORKS_EXPECTED_TO_BE_REBUILT $ALL_FRAMEWORKS
