package main

import (
	"bytes"
	"reflect"
	"testing"

	"github.com/golang/protobuf/proto"
	"github.com/golang/protobuf/protoc-gen-go/descriptor"
)

func TestPrint(t *testing.T) {
	b := new(bytes.Buffer)
	print(b, "Hello World")
	print(b, "Hello %s %d", "My Friend", 999)
	actual := b.String()
	expected := "Hello World\nHello My Friend 999\n"
	if expected != actual {
		t.Errorf("Unexpected print: %v", actual)
	}
}

func TestFilePathOnlyBaseNoExtension(t *testing.T) {
	tests := []struct {
		actual   string
		expected string
	}{
		{noExtension("foo_bar.txt"), "foo_bar"},
		{noExtension("my/filename.txt"), "my/filename"},
		{onlyBase("foo_bar.txt"), "foo_bar.txt"},
		{onlyBase("/long/path/stuff/foo_bar.txt"), "foo_bar.txt"},
		{noExtension(onlyBase("/long/path/stuff/foo_bar.txt")), "foo_bar"},
	}
	for _, tt := range tests {
		if tt.expected != tt.actual {
			t.Errorf("expected %v; actual %v", tt.expected, tt.actual)
		}
	}
}

func TestFileToRubyModules(t *testing.T) {
	tests := []struct {
		pkgName  string
		option   string
		expected []string
	}{
		{"example", "", []string{"Example"}},
		{"example.hello_world", "", []string{"Example", "HelloWorld"}},
		{"m.v.p", "", []string{"M", "V", "P"}},
		{"example", "Changed", []string{"Changed"}},
		{"example", "Other::Package", []string{"Other", "Package"}},
	}
	for _, tt := range tests {
		file := &descriptor.FileDescriptorProto{
			Package: &tt.pkgName,
			Options: makeFileOptions(tt.option),
		}

		actual := fileToRubyModules(file)
		if !reflect.DeepEqual(actual, tt.expected) {
			t.Errorf("expected %v; actual %v", tt.expected, actual)
		}
	}
}

func TestSnakeCase(t *testing.T) {
	tests := []struct {
		actual   string
		expected string
	}{
		{snakeCase("foo_bar"), "foo_bar"},
		{snakeCase("FooBar"), "foo_bar"},
		{snakeCase("fooBar"), "foo_bar"},
		{snakeCase("myLong_miXEDName"), "my_long_mi_x_e_d_name"},
	}
	for _, tt := range tests {
		if tt.expected != tt.actual {
			t.Errorf("expected %v; actual %v", tt.expected, tt.actual)
		}
	}
}

func TestCamelCase(t *testing.T) {
	tests := []struct {
		actual   string
		expected string
	}{
		{camelCase("foo_bar"), "FooBar"},
		{camelCase("FooBar"), "FooBar"},
		{camelCase("fooBar"), "FooBar"},
		{camelCase("myLong_miXEDName"), "MyLongMiXEDName"},
	}
	for _, tt := range tests {
		if tt.expected != tt.actual {
			t.Errorf("expected %v; actual %v", tt.expected, tt.actual)
		}
	}
}

func makeFileOptions(rp string) *descriptor.FileOptions {

	rpp := &RubyPackageParser{Package: rp}
	b, _ := proto.Marshal(rpp)

	return &descriptor.FileOptions{
		XXX_unrecognized: b,
	}
}
