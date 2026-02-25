class Pjfzf < Formula
  desc "Project directory navigator with fuzzy finding"
  homepage "https://github.com/kimjooeon/pjfzf"
  url "https://github.com/kimjooeon/pjfzf/archive/refs/tags/v0.1.0.tar.gz"
  sha256 ""
  license "MIT"

  depends_on "fzf"

  def install
    pkgshare.install "pj.zsh"
  end

  def caveats
    <<~EOS
      Add the following to your ~/.zshrc:
        source #{pkgshare}/pj.zsh
    EOS
  end
end
