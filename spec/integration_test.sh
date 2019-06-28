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
IOS_DESTINATION="platform=iOS Simulator,name=iPhone 7,OS=latest"
WATCH_DESTINATION="platform=watchOS Simulator,name=Apple Watch Series 4 - 40mm,OS=latest"
TEST_DESTINATION="${IOS_DESTINATION}|${WATCH_DESTINATION}"

CACHE_LOG_FILE="cache.log"
XCODEBUILD_LOG_FILE="xcodebuild.log"

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

  ../../../../bin/xcode-archive-cache inject --destination="$TEST_DESTINATION" --configuration=Debug --storage=build_cache --log-level=verbose | tee $CACHE_LOG_FILE
  check_for_positive_result "Build and cache dependencies"

  xcodebuild -workspace Test.xcworkspace -scheme Test -destination "$IOS_DESTINATION" -derivedDataPath build test | xcpretty | tee $XCODEBUILD_LOG_FILE
  check_for_positive_result "Test app"
}

expect_frameworks_to_be_rebuilt() {
  FRAMEWORKS=$(make_filename_list_enumerable "$1")
  for FRAMEWORK_NAME in $FRAMEWORKS; do
    grep -q "Touching $FRAMEWORK_NAME" $2
    check_for_positive_result "Rebuild check for $FRAMEWORK_NAME"
  done

  NUMBER_OF_REBUILT_FRAMEWORKS=$(grep "Touching" $2 | wc -l | xargs)
  NUMBER_OF_FRAMEWORKS_EXPECTED_TO_BE_REBUILT=$(echo "$FRAMEWORKS" | wc -w | xargs)
  if [ $NUMBER_OF_REBUILT_FRAMEWORKS != $NUMBER_OF_FRAMEWORKS_EXPECTED_TO_BE_REBUILT ]; then
    echo "Number of rebuilt frameworks is wrong"
    exit 1
  fi
}

expect_frameworks_not_to_be_rebuilt() {
  FRAMEWORKS=$(make_filename_list_enumerable "$1")
  for FRAMEWORK_NAME in $FRAMEWORKS; do
    grep -q "Touching $FRAMEWORK_NAME" $2
    check_for_negative_result "No-extra-rebuild check for $FRAMEWORK_NAME"
  done
}

expect_libs_to_be_rebuilt() {
  LIBS=$(make_filename_list_enumerable "$1")
  for LIB_NAME in $LIBS; do
    grep -q "Building library $LIB_NAME" $2
    check_for_positive_result "Rebuild check for $LIB_NAME"
  done

  NUMBER_OF_REBUILT_LIBS=$(grep "Building\slibrary" $2 | wc -l | xargs)
  NUMBER_OF_LIBS_EXPECTED_TO_BE_REBUILT=$(echo "$LIBS" | wc -w | xargs)
  if [ $NUMBER_OF_REBUILT_LIBS != $NUMBER_OF_LIBS_EXPECTED_TO_BE_REBUILT ]; then
    echo "Number of rebuilt libs is wrong"
    exit 1
  fi
}

expect_libs_not_to_be_rebuilt() {
  LIBS=$(make_filename_list_enumerable "$1")
  for LIB_NAME in $LIBS; do
    grep -q "Building library $LIB_NAME" $2
    check_for_negative_result "No-extra-rebuild check for $LIB_NAME"
  done
}

update_single_pod() {
  sed -i.bak "s+pod 'SDCAlertView', '= 2.5.3'+pod 'SDCAlertView', '= 2.5.4'+g" Podfile
  check_for_positive_result "Update single pod"
}

update_framework_dependency_string_and_test() {
  REPLACE_EXPRESSION="s+I'm a framework dependency+XcodeArchiveCache updated me+g"
  sed -i.bak "$REPLACE_EXPRESSION" StaticDependency/Libraries/LibraryWithFrameworkDependency/FrameworkDependency/FrameworkDependency/FrameworkThing.m
  sed -i.bak "$REPLACE_EXPRESSION" TestUITests/TestUITests.swift
}

cd $TEST_PROJECT_LOCATION

ALL_FRAMEWORKS="SDCAutoLayout.framework|RBBAnimation.framework|MRProgress.framework|SDCAlertView.framework|Pods_Test.framework|FrameworkDependency.framework|KeychainAccess.framework|Pods_TestWatch_Extension.framework"
ALL_LIBS="libLibraryWithFrameworkDependency.a|libStaticDependency.a"
perform_full_clean && perform_test
expect_frameworks_to_be_rebuilt $ALL_FRAMEWORKS $CACHE_LOG_FILE
expect_frameworks_not_to_be_rebuilt $ALL_FRAMEWORKS $XCODEBUILD_LOG_FILE
expect_libs_to_be_rebuilt $ALL_LIBS $CACHE_LOG_FILE
expect_libs_not_to_be_rebuilt $ALL_LIBS $XCODEBUILD_LOG_FILE

# update single pod, expecting it to be rebuilt
#
clean_but_leave_build_cache && update_single_pod

FRAMEWORKS_EXPECTED_TO_BE_REBUILT="SDCAlertView.framework|Pods_Test.framework"
perform_test
expect_frameworks_to_be_rebuilt $FRAMEWORKS_EXPECTED_TO_BE_REBUILT $CACHE_LOG_FILE
expect_frameworks_not_to_be_rebuilt $ALL_FRAMEWORKS $XCODEBUILD_LOG_FILE
expect_libs_to_be_rebuilt "" $CACHE_LOG_FILE
expect_libs_not_to_be_rebuilt $ALL_LIBS $XCODEBUILD_LOG_FILE

# update our own dependency code, expecting changes to propagate to the app
#
clean_but_leave_build_cache && update_framework_dependency_string_and_test

FRAMEWORKS_EXPECTED_TO_BE_REBUILT="FrameworkDependency.framework"
perform_test
expect_frameworks_to_be_rebuilt $FRAMEWORKS_EXPECTED_TO_BE_REBUILT $CACHE_LOG_FILE
expect_frameworks_not_to_be_rebuilt $ALL_FRAMEWORKS $XCODEBUILD_LOG_FILE
expect_libs_to_be_rebuilt $ALL_LIBS $CACHE_LOG_FILE
expect_libs_not_to_be_rebuilt $ALL_LIBS $XCODEBUILD_LOG_FILE
