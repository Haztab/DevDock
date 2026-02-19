cask "devdock" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/Haztab/DevDock/releases/download/v#{version}/DevDock-#{version}.dmg"
  name "DevDock"
  desc "Lightweight macOS utility to run, stop, and hot-reload mobile apps without terminal"
  homepage "https://github.com/Haztab/DevDock"

  depends_on macos: ">= :sonoma"

  app "DevDock.app"

  zap trash: [
    "~/Library/Caches/com.devdock.app",
    "~/Library/Preferences/com.devdock.app.plist",
    "~/Library/Saved Application State/com.devdock.app.savedState",
  ]
end
