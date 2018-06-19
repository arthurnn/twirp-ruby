package main

import (
	"reflect"
	"testing"
)

func TestPackageToModules(t *testing.T) {
	tests := []struct {
		pkgName string
		modules []string
	}{
		{"", nil},
		{"example", []string{"Example"}},
		{"twitch.twirp.example.helloworld", []string{"Twitch", "Twirp", "Example", "Helloworld"}},
	}

	for _, tt := range tests {
		t.Run(tt.pkgName, func(t *testing.T) {
			modules := PackageToModules(tt.pkgName)
			if got, want := modules, tt.modules; !reflect.DeepEqual(got, want) {
				t.Errorf("expected %v; got %v", want, got)
			}
		})
	}
}
