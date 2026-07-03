import Foundation

public enum Resolution {
    /// Literal path. Tilde expanded.
    case literal(String)
    /// Glob expanded with shell (zsh-style). Tilde expanded.
    case glob(String)
    /// Shell command returning newline-separated paths on stdout.
    case shell(String)
    /// Find directories named `name` under `base` whose parent dir mtime > `staleDays`.
    case stale(base: String, name: String, staleDays: Int)
    /// Find files larger than `minBytes` under `base`, excluding system dirs.
    case largeFiles(base: String, minBytes: Int64)
}

public struct Rule: Identifiable {
    public let id: String
    public let category: String
    public let description: String
    public let tier: Tier
    public let resolve: Resolution

    public init(id: String, category: String, description: String, tier: Tier, resolve: Resolution) {
        self.id = id
        self.category = category
        self.description = description
        self.tier = tier
        self.resolve = resolve
    }
}

public enum Rules {
    public static let all: [Rule] = [
        // ============ TIER 1: SAFE ============
        Rule(id: "user.caches", category: "System", description: "User cache files",
             tier: .safe, resolve: .glob("~/Library/Caches/*")),
        Rule(id: "user.logs", category: "System", description: "User log files",
             tier: .safe, resolve: .glob("~/Library/Logs/*")),
        Rule(id: "diagnostic.reports", category: "System", description: "Diagnostic reports",
             tier: .safe, resolve: .literal("~/Library/Logs/DiagnosticReports")),
        Rule(id: "crash.reporter", category: "System", description: "Crash reports",
             tier: .safe, resolve: .literal("~/Library/Application Support/CrashReporter")),
        Rule(id: "user.trash", category: "System", description: "User Trash",
             tier: .safe, resolve: .literal("~/.Trash")),
        Rule(id: "ext.trash", category: "System", description: "External drive Trash",
             tier: .safe, resolve: .shell("ls -d /Volumes/*/.Trashes 2>/dev/null")),
        Rule(id: "tmp.folders", category: "System", description: "User temp dirs",
             tier: .safe, resolve: .shell("getconf DARWIN_USER_TEMP_DIR")),
        Rule(id: "tm.snapshots", category: "System", description: "Time Machine local snapshots",
             tier: .safe, resolve: .shell("tmutil listlocalsnapshots / 2>/dev/null | sed -n 's/.*\\(com.apple.TimeMachine.[^[:space:]]*\\).*/\\1/p'")),

        // Browsers
        Rule(id: "safari.cache", category: "Browser", description: "Safari cache",
             tier: .safe, resolve: .literal("~/Library/Caches/com.apple.Safari")),
        Rule(id: "chrome.cache", category: "Browser", description: "Chrome cache",
             tier: .safe, resolve: .glob("~/Library/Application Support/Google/Chrome/*/Cache")),
        Rule(id: "chrome.codecache", category: "Browser", description: "Chrome code cache",
             tier: .safe, resolve: .glob("~/Library/Application Support/Google/Chrome/*/Code Cache")),
        Rule(id: "chrome.sw", category: "Browser", description: "Chrome service workers",
             tier: .safe, resolve: .glob("~/Library/Application Support/Google/Chrome/*/Service Worker")),
        Rule(id: "brave.cache", category: "Browser", description: "Brave cache",
             tier: .safe, resolve: .glob("~/Library/Application Support/BraveSoftware/Brave-Browser/*/Cache")),
        Rule(id: "edge.cache", category: "Browser", description: "Edge cache",
             tier: .safe, resolve: .glob("~/Library/Application Support/Microsoft Edge/*/Cache")),
        Rule(id: "arc.cache", category: "Browser", description: "Arc cache",
             tier: .safe, resolve: .glob("~/Library/Application Support/Arc/User Data/*/Cache")),
        Rule(id: "firefox.cache", category: "Browser", description: "Firefox cache",
             tier: .safe, resolve: .literal("~/Library/Caches/Firefox")),

        // Communication apps
        Rule(id: "slack.cache", category: "Comms", description: "Slack cache",
             tier: .safe, resolve: .literal("~/Library/Application Support/Slack/Cache")),
        Rule(id: "slack.sw", category: "Comms", description: "Slack service worker",
             tier: .safe, resolve: .literal("~/Library/Application Support/Slack/Service Worker")),
        Rule(id: "discord.cache", category: "Comms", description: "Discord cache",
             tier: .safe, resolve: .literal("~/Library/Application Support/discord/Cache")),
        Rule(id: "teams.cache", category: "Comms", description: "Teams cache",
             tier: .safe, resolve: .literal("~/Library/Application Support/Microsoft/Teams/Cache")),
        Rule(id: "zoom.cache", category: "Comms", description: "Zoom cache",
             tier: .safe, resolve: .literal("~/Library/Application Support/zoom.us/data")),
        Rule(id: "spotify.cache", category: "Media", description: "Spotify offline cache",
             tier: .safe, resolve: .literal("~/Library/Application Support/Spotify/PersistentCache")),

        // ============ TIER 2: REVIEW ============
        // Novice
        Rule(id: "downloads.old", category: "User", description: "Old installers in Downloads (>30d)",
             tier: .review, resolve: .shell("find ~/Downloads -maxdepth 1 -type f \\( -name '*.dmg' -o -name '*.pkg' -o -name '*.zip' -o -name '*.iso' \\) -mtime +30 2>/dev/null")),
        Rule(id: "desktop.screenshots", category: "User", description: "Old screenshots on Desktop (>30d)",
             tier: .review, resolve: .shell("find ~/Desktop -maxdepth 1 -type f -name 'Screen*.png' -mtime +30 2>/dev/null")),
        Rule(id: "mail.downloads", category: "User", description: "Mail downloads",
             tier: .review, resolve: .literal("~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads")),
        Rule(id: "messages.attachments", category: "User", description: "iMessage attachments",
             tier: .review, resolve: .literal("~/Library/Messages/Attachments")),
        Rule(id: "ios.backups", category: "User", description: "iOS device backups (often huge)",
             tier: .review, resolve: .literal("~/Library/Application Support/MobileSync/Backup")),
        Rule(id: "dmg.anywhere", category: "User", description: "DMG/PKG/ISO under home",
             tier: .review, resolve: .shell("find ~ \\( -path '*/Library/*' -o -path '*/Mobile Documents/*' \\) -prune -o -type f \\( -name '*.dmg' -o -name '*.pkg' -o -name '*.iso' \\) -size +100M -print 2>/dev/null")),

        // Xcode
        Rule(id: "xcode.deriveddata", category: "Xcode", description: "Xcode DerivedData",
             tier: .review, resolve: .literal("~/Library/Developer/Xcode/DerivedData")),
        Rule(id: "xcode.archives", category: "Xcode", description: "Xcode Archives (signed builds!)",
             tier: .review, resolve: .literal("~/Library/Developer/Xcode/Archives")),
        Rule(id: "xcode.iossupport", category: "Xcode", description: "Old iOS DeviceSupport",
             tier: .review, resolve: .literal("~/Library/Developer/Xcode/iOS DeviceSupport")),
        Rule(id: "xcode.simdevices", category: "Xcode", description: "CoreSimulator devices",
             tier: .review, resolve: .literal("~/Library/Developer/CoreSimulator/Devices")),
        Rule(id: "xcode.simcaches", category: "Xcode", description: "CoreSimulator caches",
             tier: .review, resolve: .literal("~/Library/Developer/CoreSimulator/Caches")),
        Rule(id: "xcode.simruntimes", category: "Xcode", description: "Old simulator runtimes (GB each)",
             tier: .review, resolve: .literal("/Library/Developer/CoreSimulator/Profiles/Runtimes")),

        // Package managers
        Rule(id: "pm.npm", category: "PackageMgr", description: "npm cache",
             tier: .review, resolve: .literal("~/.npm")),
        Rule(id: "pm.yarn", category: "PackageMgr", description: "yarn cache",
             tier: .review, resolve: .literal("~/Library/Caches/Yarn")),
        Rule(id: "pm.pnpm", category: "PackageMgr", description: "pnpm store",
             tier: .review, resolve: .literal("~/Library/pnpm/store")),
        Rule(id: "pm.pip.user", category: "PackageMgr", description: "pip cache (~/.cache)",
             tier: .review, resolve: .literal("~/.cache/pip")),
        Rule(id: "pm.pip.lib", category: "PackageMgr", description: "pip cache (Library)",
             tier: .review, resolve: .literal("~/Library/Caches/pip")),
        Rule(id: "pm.cocoapods", category: "PackageMgr", description: "CocoaPods cache",
             tier: .review, resolve: .literal("~/Library/Caches/CocoaPods")),
        Rule(id: "pm.carthage", category: "PackageMgr", description: "Carthage cache",
             tier: .review, resolve: .literal("~/Library/Caches/org.carthage.CarthageKit")),
        Rule(id: "pm.brew.cache", category: "PackageMgr", description: "Homebrew downloads",
             tier: .review, resolve: .shell("brew --cache 2>/dev/null")),
        Rule(id: "pm.cargo.registry", category: "PackageMgr", description: "Cargo registry cache",
             tier: .review, resolve: .literal("~/.cargo/registry/cache")),
        Rule(id: "pm.cargo.src", category: "PackageMgr", description: "Cargo registry sources",
             tier: .review, resolve: .literal("~/.cargo/registry/src")),
        Rule(id: "pm.go.build", category: "PackageMgr", description: "Go build cache",
             tier: .review, resolve: .literal("~/Library/Caches/go-build")),
        Rule(id: "pm.go.mod", category: "PackageMgr", description: "Go module cache",
             tier: .review, resolve: .literal("~/go/pkg/mod")),
        Rule(id: "pm.gradle", category: "PackageMgr", description: "Gradle caches",
             tier: .review, resolve: .literal("~/.gradle/caches")),
        Rule(id: "pm.maven", category: "PackageMgr", description: "Maven local repo",
             tier: .review, resolve: .literal("~/.m2/repository")),
        Rule(id: "pm.gem", category: "PackageMgr", description: "Ruby gems",
             tier: .review, resolve: .literal("~/.gem")),
        Rule(id: "pm.bundle", category: "PackageMgr", description: "Bundler cache",
             tier: .review, resolve: .literal("~/.bundle/cache")),
        Rule(id: "pm.pub", category: "PackageMgr", description: "Pub (Flutter/Dart) cache",
             tier: .review, resolve: .literal("~/.pub-cache")),

        // Stale project dirs (heuristic-ish but in review tier since deletes are scoped)
        Rule(id: "stale.node_modules", category: "Project", description: "Stale node_modules (parent >90d)",
             tier: .review, resolve: .stale(base: "~", name: "node_modules", staleDays: 90)),
        Rule(id: "stale.target", category: "Project", description: "Stale Rust target/ (parent >90d)",
             tier: .review, resolve: .stale(base: "~", name: "target", staleDays: 90)),
        Rule(id: "stale.venv", category: "Project", description: "Stale Python venvs (parent >90d)",
             tier: .review, resolve: .stale(base: "~", name: ".venv", staleDays: 90)),
        Rule(id: "stale.pycache", category: "Project", description: "__pycache__ dirs",
             tier: .review, resolve: .stale(base: "~", name: "__pycache__", staleDays: 30)),
        Rule(id: "stale.next", category: "Project", description: "Stale Next.js .next builds (>30d)",
             tier: .review, resolve: .stale(base: "~", name: ".next", staleDays: 30)),

        // IDEs
        Rule(id: "ide.vscode.cache", category: "IDE", description: "VS Code caches",
             tier: .review, resolve: .glob("~/Library/Application Support/Code/{Cache,CachedData,CachedExtensions,logs}")),
        Rule(id: "ide.cursor.cache", category: "IDE", description: "Cursor caches",
             tier: .review, resolve: .glob("~/Library/Application Support/Cursor/{Cache,CachedData,CachedExtensions,logs}")),
        Rule(id: "ide.windsurf.cache", category: "IDE", description: "Windsurf caches",
             tier: .review, resolve: .glob("~/Library/Application Support/Windsurf/{Cache,CachedData,CachedExtensions,logs}")),
        Rule(id: "ide.jetbrains.caches", category: "IDE", description: "JetBrains caches",
             tier: .review, resolve: .glob("~/Library/Caches/JetBrains/*")),
        Rule(id: "ide.jetbrains.logs", category: "IDE", description: "JetBrains logs",
             tier: .review, resolve: .glob("~/Library/Logs/JetBrains/*")),

        // Containers / VMs
        Rule(id: "docker.data", category: "Containers", description: "Docker VM data",
             tier: .review, resolve: .literal("~/Library/Containers/com.docker.docker/Data/vms")),
        Rule(id: "colima", category: "Containers", description: "Colima data",
             tier: .review, resolve: .literal("~/.colima")),
        Rule(id: "vm.parallels", category: "VM", description: "Parallels VMs (.pvm)",
             tier: .review, resolve: .shell("find ~ -maxdepth 4 -type d -name '*.pvm' 2>/dev/null")),
        Rule(id: "vm.vmware", category: "VM", description: "VMware VMs (.vmwarevm)",
             tier: .review, resolve: .shell("find ~ -maxdepth 4 -type d -name '*.vmwarevm' 2>/dev/null")),
        Rule(id: "vm.utm", category: "VM", description: "UTM VMs (.utm)",
             tier: .review, resolve: .shell("find ~ -maxdepth 4 -type d -name '*.utm' 2>/dev/null")),

        // Android
        Rule(id: "android.systemimages", category: "Android", description: "Android emulator system images",
             tier: .review, resolve: .literal("~/Library/Android/sdk/system-images")),
        Rule(id: "android.avd", category: "Android", description: "Android Virtual Devices",
             tier: .review, resolve: .literal("~/.android/avd")),

        // Large-file / large-folder / old-file scans are opt-in and generated
        // dynamically by the Scanner from ScanOptions (Review tier), not here.

        // ============ TIER 4: DANGEROUS ============
        Rule(id: "sys.vm", category: "System", description: "Swap/sleepimage (NEEDS sudo, system-managed)",
             tier: .dangerous, resolve: .literal("/private/var/vm")),
        Rule(id: "sys.caches", category: "System", description: "System-wide /Library/Caches",
             tier: .dangerous, resolve: .literal("/Library/Caches"))
    ]
}
