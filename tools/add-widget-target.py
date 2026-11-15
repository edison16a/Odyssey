"""
Adds the OdysseyWidgets extension target to Odyssey.xcodeproj and shares the
Shared folder between the app and the widgets. Run once; it refuses to run
twice. Kept in the repo so the change is reviewable.
"""
import re, sys

path = "Odyssey.xcodeproj/project.pbxproj"
s = open(path).read()
if "OdysseyWidgetsExtension" in s:
    sys.exit("OdysseyWidgets is already in the project")

ids = iter("633B8F%02X309D066F00AE36FF" % n for n in range(0xE0, 0x100))
APPEX, G_WIDGETS, G_SHARED, BF_EMBED, PH_EMBED, PROXY, DEP, TARGET, SRC, FW, RES, DBG, REL, CFGLIST = [next(ids) for _ in range(14)]
APP = "633B8FA8309D066D00AE36FF"
PROJECT = "633B8FA1309D066D00AE36FF"

def insert_section_end(section, text):
    global s
    marker = "/* End %s section */" % section
    assert marker in s, marker
    s = s.replace(marker, text + marker, 1)

insert_section_end("PBXContainerItemProxy", """		%s /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = %s /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = %s;
			remoteInfo = OdysseyWidgetsExtension;
		};
""" % (PROXY, PROJECT, TARGET))

s = s.replace("/* Begin PBXContainerItemProxy section */", """/* Begin PBXBuildFile section */
		%s /* OdysseyWidgetsExtension.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = %s /* OdysseyWidgetsExtension.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */""" % (BF_EMBED, APPEX), 1)

s = s.replace("/* Begin PBXFileReference section */", """/* Begin PBXCopyFilesBuildPhase section */
		%s /* Embed Foundation Extensions */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				%s /* OdysseyWidgetsExtension.appex in Embed Foundation Extensions */,
			);
			name = "Embed Foundation Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */""" % (PH_EMBED, BF_EMBED), 1)

insert_section_end("PBXFileReference", """		%s /* OdysseyWidgetsExtension.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = OdysseyWidgetsExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; };
""" % APPEX)

insert_section_end("PBXFileSystemSynchronizedRootGroup", """		%s /* OdysseyWidgets */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = OdysseyWidgets;
			sourceTree = "<group>";
		};
		%s /* Shared */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = Shared;
			sourceTree = "<group>";
		};
""" % (G_WIDGETS, G_SHARED))

insert_section_end("PBXFrameworksBuildPhase", """		%s /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
""" % FW)

# Main group and products
s = s.replace("""				633B8FAB309D066D00AE36FF /* Odyssey */,
				633B8FBB309D066F00AE36FF /* OdysseyTests */,""", """				633B8FAB309D066D00AE36FF /* Odyssey */,
				%s /* Shared */,
				%s /* OdysseyWidgets */,
				633B8FBB309D066F00AE36FF /* OdysseyTests */,""" % (G_SHARED, G_WIDGETS), 1)
s = s.replace("""				633B8FC2309D066F00AE36FF /* OdysseyUITests.xctest */,
			);
			name = Products;""", """				633B8FC2309D066F00AE36FF /* OdysseyUITests.xctest */,
				%s /* OdysseyWidgetsExtension.appex */,
			);
			name = Products;""" % APPEX, 1)

# App target: embed phase, dependency, shared folder
app_old = """				633B8FA7309D066D00AE36FF /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				633B8FAB309D066D00AE36FF /* Odyssey */,
			);"""
assert app_old in s
s = s.replace(app_old, """				633B8FA7309D066D00AE36FF /* Resources */,
				%s /* Embed Foundation Extensions */,
			);
			buildRules = (
			);
			dependencies = (
				%s /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				633B8FAB309D066D00AE36FF /* Odyssey */,
				%s /* Shared */,
			);""" % (PH_EMBED, DEP, G_SHARED), 1)

insert_section_end("PBXNativeTarget", """		%s /* OdysseyWidgetsExtension */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = %s /* Build configuration list for PBXNativeTarget "OdysseyWidgetsExtension" */;
			buildPhases = (
				%s /* Sources */,
				%s /* Frameworks */,
				%s /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				%s /* OdysseyWidgets */,
				%s /* Shared */,
			);
			name = OdysseyWidgetsExtension;
			packageProductDependencies = (
			);
			productName = OdysseyWidgetsExtension;
			productReference = %s /* OdysseyWidgetsExtension.appex */;
			productType = "com.apple.product-type.app-extension";
		};
""" % (TARGET, CFGLIST, SRC, FW, RES, G_WIDGETS, G_SHARED, APPEX))

s = s.replace("""					633B8FC1309D066F00AE36FF = {
						CreatedOnToolsVersion = 26.6;
						TestTargetID = 633B8FA8309D066D00AE36FF;
					};""", """					633B8FC1309D066F00AE36FF = {
						CreatedOnToolsVersion = 26.6;
						TestTargetID = 633B8FA8309D066D00AE36FF;
					};
					%s = {
						CreatedOnToolsVersion = 26.6;
					};""" % TARGET, 1)
s = s.replace("""				633B8FC1309D066F00AE36FF /* OdysseyUITests */,
			);
		};""", """				633B8FC1309D066F00AE36FF /* OdysseyUITests */,
				%s /* OdysseyWidgetsExtension */,
			);
		};""" % TARGET, 1)

insert_section_end("PBXResourcesBuildPhase", """		%s /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
""" % RES)
insert_section_end("PBXSourcesBuildPhase", """		%s /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
""" % SRC)
insert_section_end("PBXTargetDependency", """		%s /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = %s /* OdysseyWidgetsExtension */;
			targetProxy = %s /* PBXContainerItemProxy */;
		};
""" % (DEP, TARGET, PROXY))

def ext_config(cid, name):
    return """		%s /* %s */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_ENTITLEMENTS = Config/OdysseyWidgets.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 4KBULT3MU8;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = "Config/OdysseyWidgets-Info.plist";
				INFOPLIST_KEY_CFBundleDisplayName = Odyssey;
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				IPHONEOS_DEPLOYMENT_TARGET = 18.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.edisonlaw.Odyssey.OdysseyWidgets;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = %s;
		};
""" % (cid, name, name)

insert_section_end("XCBuildConfiguration", ext_config(DBG, "Debug") + ext_config(REL, "Release"))
insert_section_end("XCConfigurationList", """		%s /* Build configuration list for PBXNativeTarget "OdysseyWidgetsExtension" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				%s /* Debug */,
				%s /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
""" % (CFGLIST, DBG, REL))

# App target settings: permissions, Live Activities, URL scheme plist, entitlements, portrait only.
app_settings_old = """				INFOPLIST_KEY_CFBundleDisplayName = Odyssey;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;"""
app_settings_new = """				CODE_SIGN_ENTITLEMENTS = Config/Odyssey.entitlements;
				INFOPLIST_FILE = "Config/Odyssey-Info.plist";
				INFOPLIST_KEY_CFBundleDisplayName = Odyssey;
				INFOPLIST_KEY_NSCameraUsageDescription = "Odyssey uses the camera for your check-in photos and the walkthrough videos you choose to share.";
				INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Odyssey uses your location to find places around you, measure how far they are and confirm you are there when you check in.";
				INFOPLIST_KEY_NSMicrophoneUsageDescription = "Odyssey records sound with walkthrough videos so other explorers know how busy a place feels.";
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "Odyssey lets you pick a profile photo from your library.";
				INFOPLIST_KEY_NSSupportsLiveActivities = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;"""
assert s.count(app_settings_old) == 2
s = s.replace(app_settings_old, app_settings_new)
s = s.replace('INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";',
              "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;")
open(path, "w").write(s)
print("added OdysseyWidgetsExtension", TARGET)
