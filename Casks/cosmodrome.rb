cask "cosmodrome" do
  version "0.3.0"
  sha256 "65d133661ffa11d98669be15fc2ce70390f3daaa7949427952b91da4dbe723c1"

  url "https://github.com/rinaldofesta/cosmodrome/releases/download/v#{version}/Cosmodrome.dmg"
  name "Cosmodrome"
  desc "Native macOS terminal for developers running multiple AI agents in parallel"
  homepage "https://github.com/rinaldofesta/cosmodrome"

  depends_on macos: ">= :sonoma"

  app "Cosmodrome.app"

  binary "#{appdir}/Cosmodrome.app/Contents/MacOS/cosmoctl", target: "cosmoctl"

  zap trash: [
    "~/Library/Application Support/Cosmodrome",
    "~/Library/Preferences/com.cosmodrome.terminal.plist",
  ]
end
