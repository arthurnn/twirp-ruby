package main

import (
	"bytes"
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/golang/protobuf/proto"
	"github.com/golang/protobuf/protoc-gen-go/descriptor"
	plugin_go "github.com/golang/protobuf/protoc-gen-go/plugin"
	"github.com/stretchr/testify/require"
)

func loadTestPb(t *testing.T) []*descriptor.FileDescriptorProto {
	f, err := ioutil.ReadFile(filepath.Join("testdata", "fileset.pb"))
	require.NoError(t, err, "unable to read testdata protobuf file")

	set := new(descriptor.FileDescriptorSet)
	err = proto.Unmarshal(f, set)
	require.NoError(t, err, "unable to unmarshal testdata protobuf file")

	return set.File
}

func testGeneratorRubyTypes(t *testing.T) *generator {
	genReq := &plugin_go.CodeGeneratorRequest{
		FileToGenerate: []string{"rubytypes.proto"},
		ProtoFile:      loadTestPb(t),
	}
	return newGenerator(genReq)
}

func testGeneratorService(t *testing.T) *generator {
	genReq := &plugin_go.CodeGeneratorRequest{
		FileToGenerate: []string{"service.proto"},
		ProtoFile:      loadTestPb(t),
	}
	return newGenerator(genReq)
}

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
		expected  string
	}{
		{".twirp.rubytypes.foo.my_message", "Foo::MyMessage"},
		{".twirp.rubytypes.m.v.p99.hello_world", "M::V::P99::HelloWorld"},
		{".google.protobuf.Empty", "Google::Protobuf::Empty"},
	}

	g := testGeneratorRubyTypes(t)
	g.findProtoFilesToGenerate()

	for _, tt := range tests {
		actual := g.toRubyType(tt.protoType)
		if !reflect.DeepEqual(actual, tt.expected) {
			t.Errorf("expected %v; actual %v", tt.expected, actual)
		}
	}
}

func TestGenerateService(t *testing.T) {
	g := testGeneratorService(t)

	response := g.Generate()
	require.NotNil(t, response, "Generator response is nil")

	require.Empty(t, response.Error, "Generator response has errors")
	require.Len(t, response.File, 1)

	file := response.File[0]
	expectedContent, err := os.ReadFile(filepath.Join("testdata", "service_twirp.rb"))
	require.NoError(t, err, "unable to read testdata/service_twirp.rb")
	require.Equal(t, *file.Content, string(expectedContent))
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
