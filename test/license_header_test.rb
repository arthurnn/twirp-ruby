require 'minitest/autorun'

# Check that all .rb files in /lib have the license header.
class LicenseHeaderTest < Minitest::Test

  LICENSE_HEADER_LINES = [
    "# Copyright 2018 Twitch Interactive, Inc.  All Rights Reserved.",
    "#",
    "# Licensed under the Apache License, Version 2.0 (the \"License\"). You may not",
    "# use this file except in compliance with the License. A copy of the License is",
    "# located at",
    "#",
    "#     http://www.apache.org/licenses/LICENSE-2.0",
    "#",
    "# or in the \"license\" file accompanying this file. This file is distributed on",
    "# an \"AS IS\" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either",
    "# express or implied. See the License for the specific language governing",
    "# permissions and limitations under the License.",
  ]

  def test_files_have_license_header
    test_dir = File.dirname(__FILE__)

    files = Dir.glob("#{test_dir}/../lib/**/*.rb")
    assert_operator files.size, :>, 1, "at least one file was loaded, otherwise the glob expression may be failing"

    files.each do |filepath|
      lines = File.read(filepath).split("\n")
      assert_operator lines.size, :>, LICENSE_HEADER_LINES.size, "has license header"
      LICENSE_HEADER_LINES.each_with_index do |license_line, i|
        file_line = lines[i]
        assert_equal license_line, file_line
      end
    end
  end

end
