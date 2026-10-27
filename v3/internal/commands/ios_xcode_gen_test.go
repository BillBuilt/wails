package commands

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"howett.net/plist"
)

func TestIOSXcodeProjectRetainsObjectiveCClasses(t *testing.T) {
	output := filepath.Join(t.TempDir(), "project.pbxproj")
	err := renderTemplateTo(
		updatableBuildAssets,
		"updatable_build_assets/ios/project.pbxproj.tmpl",
		output,
		iOSProjectConfig{ProductName: "Test App", ProductIdentifier: "com.wails.test"},
	)
	require.NoError(t, err)

	data, err := os.ReadFile(output)
	require.NoError(t, err)
	project := string(data)

	for _, configuration := range []string{"Debug", "Release"} {
		t.Run(configuration, func(t *testing.T) {
			marker := "/* " + configuration + " */ = {"
			_, remainder, found := strings.Cut(project, marker)
			require.True(t, found, "%s build configuration should be present", configuration)
			buildSettings, _, found := strings.Cut(remainder, "\n\t\t};")
			require.True(t, found, "%s build configuration should be complete", configuration)

			assert.Equal(t, 1, strings.Count(buildSettings, "OTHER_LDFLAGS = ("),
				"build configuration should define linker flags once")
			assert.Equal(t, 1, strings.Count(buildSettings, `"$(inherited)",`),
				"build configuration should preserve inherited linker flags")
			assert.Equal(t, 1, strings.Count(buildSettings, `"-ObjC",`),
				"build configuration should retain Objective-C classes from the Go archive")
		})
	}
}

// A valid static scene configuration is required by the iOS 27 launch validator.
func TestIOSPlistsDeclareSceneLifecycle(t *testing.T) {
	for _, name := range []string{"Info.plist.tmpl", "Info.dev.plist.tmpl"} {
		t.Run(name, func(t *testing.T) {
			output := filepath.Join(t.TempDir(), "Info.plist")
			require.NoError(t, renderTemplateTo(updatableBuildAssets,
				"updatable_build_assets/ios/"+name, output,
				iOSProjectConfig{ProductName: "Test App", ProductIdentifier: "com.wails.test"}))
			data, err := os.ReadFile(output)
			require.NoError(t, err)
			var info struct {
				Manifest struct {
					Multiple       bool `plist:"UIApplicationSupportsMultipleScenes"`
					Configurations map[string][]struct {
						Name     string `plist:"UISceneConfigurationName"`
						Delegate string `plist:"UISceneDelegateClassName"`
					} `plist:"UISceneConfigurations"`
				} `plist:"UIApplicationSceneManifest"`
			}
			_, err = plist.Unmarshal(data, &info)
			require.NoError(t, err)
			require.False(t, info.Manifest.Multiple)
			configs := info.Manifest.Configurations["UIWindowSceneSessionRoleApplication"]
			require.Len(t, configs, 1)
			assert.Equal(t, "Wails", configs[0].Name)
			assert.Equal(t, "WailsSceneDelegate", configs[0].Delegate)
		})
	}
}
