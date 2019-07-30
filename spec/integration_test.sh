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

ROOT_PWD=$PWD
TEST_PROJECT_LOCATION="$PWD/fixtures/test_project/Test"
IOS_DESTINATION="platform=iOS Simulator,name=iPhone 7,OS=latest"
WATCH_DESTINATION="platform=watchOS Simulator,name=Apple Watch Series 4 - 40mm,OS=latest"
TEST_DESTINATION="${IOS_DESTINATION}|${WATCH_DESTINATION}"

CACHE_LOG_FILE="$TEST_PROJECT_LOCATION/cache.log"
XCODEBUILD_LOG_FILE="$TEST_PROJECT_LOCATION/xcodebuild.log"

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

install_pods() {
  pod install
  check_for_positive_result "Install pods"
}

inject_cache() {
  "$ROOT_PWD/../bin/xcode-archive-cache" inject --destination="$TEST_DESTINATION" --configuration=Debug --storage="$TEST_PROJECT_LOCATION/build_cache" --log-level=verbose | tee $CACHE_LOG_FILE
  check_for_positive_result "Build and cache dependencies"
}

test_target() {
  xcodebuild -workspace Test.xcworkspace -scheme "$1" -destination "$IOS_DESTINATION" -derivedDataPath build test | xcpretty | tee $XCODEBUILD_LOG_FILE
  check_for_positive_result "Test $1"
}

perform_app_test() {
  install_pods
  inject_cache
  test_target "Test"
}

perform_both_apps_test() {
  perform_app_test
  test_target "Test2"
}

perform_static_dependency_test() {
  install_pods

  cd StaticDependency
  check_for_positive_result "Go to StaticDependency dir"
  inject_cache
  cd -
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

add_second_app_to_cachefile() {
  mv Cachefile_two_apps Cachefile
}

add_sibling_import() {
  sed -i.bak "s+// to be removed during tests: ++g" StaticDependency/Libraries/LibraryThatUsesSibling/LibraryThatUsesSibling/LibraryThatUsesSibling.h
  check_for_positive_result "Add sibling import"
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
check_for_positive_result "Go to test project dir"

ALL_FRAMEWORKS="SDCAutoLayout.framework|RBBAnimation.framework|MRProgress.framework|SDCAlertView.framework|Pods_Test.framework|FrameworkDependency.framework|KeychainAccess.framework|Pods_TestWatch_Extension.framework"
ALL_LIBS="libLibraryWithFrameworkDependency.a|libStaticDependency.a|libLibraryThatUsesSibling.a"
perform_full_clean && perform_app_test
expect_frameworks_to_be_rebuilt $ALL_FRAMEWORKS $CACHE_LOG_FILE
expect_frameworks_not_to_be_rebuilt $ALL_FRAMEWORKS $XCODEBUILD_LOG_FILE
expect_libs_to_be_rebuilt $ALL_LIBS $CACHE_LOG_FILE
expect_libs_not_to_be_rebuilt $ALL_LIBS $XCODEBUILD_LOG_FILE

# add target with shared dependencies to cachefile
# all dependencies are shared so only umbrella Pods framework should be rebuilt
#
clean_but_leave_build_cache && add_second_app_to_cachefile && perform_both_apps_test
expect_frameworks_to_be_rebuilt "Pods_Test2.framework" $CACHE_LOG_FILE
expect_frameworks_not_to_be_rebuilt $ALL_FRAMEWORKS $XCODEBUILD_LOG_FILE
expect_libs_to_be_rebuilt "" $CACHE_LOG_FILE
expect_libs_not_to_be_rebuilt $ALL_LIBS $XCODEBUILD_LOG_FILE

# add sibling import, expecting changed library to be rebuilt
#
LIBS_EXPECTED_TO_BE_REBUILT="libLibraryThatUsesSibling.a|libStaticDependency.a"
clean_but_leave_build_cache && add_sibling_import && perform_app_test
expect_frameworks_to_be_rebuilt "" $CACHE_LOG_FILE
expect_frameworks_not_to_be_rebuilt $ALL_FRAMEWORKS $XCODEBUILD_LOG_FILE
expect_libs_to_be_rebuilt $LIBS_EXPECTED_TO_BE_REBUILT $CACHE_LOG_FILE
expect_libs_not_to_be_rebuilt $ALL_LIBS $XCODEBUILD_LOG_FILE

# update single pod, expecting it to be rebuilt
#
clean_but_leave_build_cache && update_single_pod

FRAMEWORKS_EXPECTED_TO_BE_REBUILT="SDCAlertView.framework|Pods_Test.framework"
perform_app_test
expect_frameworks_to_be_rebuilt $FRAMEWORKS_EXPECTED_TO_BE_REBUILT $CACHE_LOG_FILE
expect_frameworks_not_to_be_rebuilt $ALL_FRAMEWORKS $XCODEBUILD_LOG_FILE
expect_libs_to_be_rebuilt "" $CACHE_LOG_FILE
expect_libs_not_to_be_rebuilt $ALL_LIBS $XCODEBUILD_LOG_FILE

# update our own dependency code, expecting changes to propagate to the app
#
clean_but_leave_build_cache && update_framework_dependency_string_and_test

FRAMEWORKS_EXPECTED_TO_BE_REBUILT="FrameworkDependency.framework"
LIBS_EXPECTED_TO_BE_REBUILT="libLibraryWithFrameworkDependency.a|libStaticDependency.a"
perform_app_test
expect_frameworks_to_be_rebuilt $FRAMEWORKS_EXPECTED_TO_BE_REBUILT $CACHE_LOG_FILE
expect_frameworks_not_to_be_rebuilt $ALL_FRAMEWORKS $XCODEBUILD_LOG_FILE
expect_libs_to_be_rebuilt $LIBS_EXPECTED_TO_BE_REBUILT $CACHE_LOG_FILE
expect_libs_not_to_be_rebuilt $ALL_LIBS $XCODEBUILD_LOG_FILE

# ask for StaticDependency rebuild, expecting nothing to be rebuilt
#
clean_but_leave_build_cache
perform_static_dependency_test
expect_frameworks_to_be_rebuilt "" $CACHE_LOG_FILE
expect_libs_to_be_rebuilt "" $CACHE_LOG_FILE
