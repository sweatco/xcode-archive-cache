#! /bin/bash
set -exo

check_result() {
  if [ $? != 0 ]; then
    echo $1 failed
    exit 1
  else
    echo $1 succeeded
  fi
}

TEST_PROJECT_LOCATION="fixtures/test_project/Test"
TEST_DESTINATION="platform=iOS Simulator,name=iPhone 7,OS=latest"

perform_test() {
  cd $TEST_PROJECT_LOCATION

  git clean -xdf -e "build_cache" . && git checkout HEAD -- .
  check_result "Reset project contents"

  pod install
  check_result "Install pods"

  xcode-archive-cache inject --destination="$TEST_DESTINATION" --action=build --log-level=verbose
  check_result "Build and cache dependencies"

  xcodebuild -workspace Test.xcworkspace -scheme Test -destination "$TEST_DESTINATION" -derivedDataPath build test | xcpretty
  check_result "Test app"

  # check cached dependencies
  # ...

  cd - > /dev/null
}

perform_test
