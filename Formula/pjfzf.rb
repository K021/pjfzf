class Pjfzf < Formula
  desc "Project directory navigator with fuzzy finding"
  homepage "https://github.com/K021/pjfzf"
  url "https://github.com/K021/pjfzf/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "9d9d90f76a129c9a670b24be220eb6fe784753c46a738f42348600966d8d9893"
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
