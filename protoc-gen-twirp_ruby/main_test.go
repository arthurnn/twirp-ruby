package main

import (
	"bytes"
	"reflect"
	"testing"
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

func TestToRubyType(t *testing.T) {
	tests := []struct {
		protoType string
		modules   []string
		expected  string
	}{
		{"", []string{}, ""},
		{"", []string{"Foo", "Bar"}, ""},
		{".foo.my_message", []string{}, "Foo::MyMessage"},
		{".foo.my_message", []string{"Foo"}, "MyMessage"},
		{"m.v.p99.hello_world", []string{}, "M::V::P99::HelloWorld"},
		{"m.v.p99.hello_world", []string{"M", "V"}, "P99::HelloWorld"},
		{"m.v.p99.hello_world", []string{"M", "V", "P99"}, "HelloWorld"},
		{"m.v.p99.hello_world", []string{"P99"}, "M::V::P99::HelloWorld"},
		{"google.protobuf.Empty", []string{"Foo"}, "Google::Protobuf::Empty"},
	}
	for _, tt := range tests {
		actual := toRubyType(tt.protoType, tt.modules)
		if !reflect.DeepEqual(actual, tt.expected) {
			t.Errorf("expected %v; actual %v", tt.expected, actual)
		}
	}
}

func TestSplitRubyConstants(t *testing.T) {
	tests := []struct {
		pkgName  string
		expected []string
	}{
		{"", []string{}},
		{"example", []string{"Example"}},
		{"example.hello_world", []string{"Example", "HelloWorld"}},
		{"m.v.p", []string{"M", "V", "P"}},
		{"p99.a2z", []string{"P99", "A2z"}},
	}
	for _, tt := range tests {
		actual := splitRubyConstants(tt.pkgName)
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
		{camelCase("a2z"), "A2z"},
		{camelCase("a_2z"), "A2z"},
	}
	for _, tt := range tests {
		if tt.expected != tt.actual {
			t.Errorf("expected %v; actual %v", tt.expected, tt.actual)
		}
	}
}
