"""Real Git/Dart/SSH integration checks. No third-party Python dependencies.

Run: uv run --offline --no-project --python 3.13 python scripts/test_git_hooks.py
All test repositories and temporary SSH keys stay in a new ignored build/
directory. No user Git configuration, hooks, agent, or repository is modified.
"""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


PROJECT = Path(__file__).resolve().parents[1]
BASH = (
    Path("C:/Program Files/Git/bin/bash.exe")
    if os.name == "nt"
    else Path(shutil.which("bash") or "bash")
)
SSH_KEYGEN = (
    BASH.parent.parent / "usr/bin/ssh-keygen.exe"
    if os.name == "nt"
    else Path(shutil.which("ssh-keygen") or "ssh-keygen")
)


class Repo:
    def __init__(self, suite: "GitHooksTests", *, signed: bool = False):
        self.suite = suite
        self.path = Path(tempfile.mkdtemp(prefix="repo with spaces ", dir=suite.run_root))
        self.env = suite.env.copy()
        self.git("init", "-q", "--initial-branch=main")
        for key, value in {
            "user.name": "Hook Tests",
            "user.email": "hook-tests@example.invalid",
            "core.autocrlf": "false",
            "gc.auto": "0",
            "commit.gpgsign": str(signed).lower(),
            "gpg.format": "ssh",
            "gpg.ssh.program": SSH_KEYGEN.as_posix(),
            "user.signingkey": suite.key.as_posix(),
            "gpg.ssh.allowedSignersFile": suite.allowed_signers.as_posix(),
        }.items():
            self.git("config", "--local", key, value)
        shutil.copytree(PROJECT / ".githooks", self.path / ".githooks")
        self.write("pubspec.yaml", "name: hook_test\nversion: 1.0.0+1\n")
        self.write("file with spaces.dart", "void main() {}\n")
        self.write("notes.txt", "seed\n")
        self.git("add", ".")
        self.git("commit", "-qm", "seed")
        self.git("update-ref", "refs/remotes/origin/main", "HEAD")
        self.run([str(BASH), (PROJECT / "scripts/install-git-hooks.sh").as_posix()])

    def run(self, args: list[str], *, ok: bool = True) -> subprocess.CompletedProcess:
        result = subprocess.run(
            args,
            cwd=self.path,
            env=self.env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=60,
        )
        if ok and result.returncode:
            raise AssertionError(
                f"{args!r} failed ({result.returncode}) in {self.path}\n"
                f"{result.stdout.decode(errors='replace')}"
                f"{result.stderr.decode(errors='replace')}"
            )
        return result

    def git(self, *args: str, ok: bool = True) -> str:
        result = self.run(["git", *args], ok=ok)
        return result.stdout.decode("utf-8", errors="replace").strip()

    def write(self, name: str, content: str) -> None:
        (self.path / name).write_bytes(content.encode("utf-8"))

    def change(self, name: str = "notes.txt", content: str = "changed\n") -> None:
        self.write(name, content)
        self.git("add", "--", name)

    def number(self) -> int:
        content = self.git("show", "HEAD:pubspec.yaml")
        return int(next(line for line in content.splitlines() if line.startswith("version:")).split("+")[1])

    def count(self) -> int:
        return int(self.git("rev-list", "--first-parent", "--count", "HEAD"))

    def assert_clean(self) -> None:
        self.suite.assertEqual(self.git("status", "--porcelain"), "")

    def assert_signature(self, signed: bool = True) -> None:
        content = self.git("cat-file", "commit", "HEAD")
        self.suite.assertEqual("\ngpgsig " in content, signed)
        if signed:
            self.git("verify-commit", "HEAD")

    def snapshot(self) -> tuple:
        return (
            self.git("rev-parse", "HEAD"),
            self.git("write-tree"),
            (self.path / "pubspec.yaml").read_bytes(),
            (self.path / "file with spaces.dart").read_bytes(),
            (self.path / "notes.txt").read_bytes(),
        )


class GitHooksTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        output = PROJECT / "build/git-hook-tests"
        output.mkdir(parents=True, exist_ok=True)
        cls.run_root = Path(tempfile.mkdtemp(prefix="run with spaces ", dir=output))
        print(f"\nIsolated test data retained at: {cls.run_root}", flush=True)
        cls.env = {
            key: value
            for key, value in os.environ.items()
            if not key.startswith("GIT_")
            and key not in {"SSH_AUTH_SOCK", "SSH_AGENT_PID", "GPG_TTY"}
        }
        empty_config = cls.run_root / "empty-git-config"
        empty_config.write_text("", encoding="utf-8")
        cls.env.update(
            GIT_CONFIG_NOSYSTEM="1",
            GIT_CONFIG_GLOBAL=str(empty_config),
            GIT_CONFIG_SYSTEM=str(empty_config),
            GIT_TERMINAL_PROMPT="0",
            GIT_EDITOR="true",
        )
        cls.key = cls.run_root / "isolated_ed25519"
        subprocess.run(
            [str(SSH_KEYGEN), "-q", "-t", "ed25519", "-N", "", "-f", str(cls.key)],
            env=cls.env,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=30,
        )
        cls.allowed_signers = cls.run_root / "allowed_signers"
        cls.allowed_signers.write_text(
            "hook-tests@example.invalid " + cls.key.with_suffix(".pub").read_text(),
            encoding="utf-8",
        )

    def test_normal_commit_and_real_dart_with_spaces(self) -> None:
        repo = Repo(self)
        repo.change("file with spaces.dart", "void main(){print('hello');}\n")
        before = len(repo.git("reflog", "--format=%H").splitlines())
        repo.git("commit", "-qm", "ordinary")
        self.assertEqual(repo.number(), 2)
        self.assertEqual(repo.count(), 2)
        self.assertEqual(len(repo.git("reflog", "--format=%H").splitlines()), before + 1)
        self.assertEqual(
            repo.git("show", "HEAD:file with spaces.dart"),
            "void main() {\n  print('hello');\n}",
        )
        repo.assert_clean()

    def test_empty_commit_does_not_create_version_commit(self) -> None:
        repo = Repo(self)
        before = repo.snapshot()
        result = repo.run(["git", "commit", "-m", "empty"], ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(repo.snapshot(), before)

    def test_repeated_amend_with_and_without_staged_changes(self) -> None:
        repo = Repo(self)
        repo.change()
        repo.git("commit", "-qm", "ordinary")
        for index in range(2):
            repo.change(content=f"amend {index}\n")
            repo.git("commit", "--amend", "--no-edit", "-q")
            self.assertEqual(repo.number(), 2)
            self.assertEqual(repo.count(), 2)
            repo.assert_clean()
        before = len(repo.git("reflog", "--format=%H").splitlines())
        repo.git("commit", "--amend", "--no-edit", "-q")
        self.assertEqual(len(repo.git("reflog", "--format=%H").splitlines()), before + 1)
        self.assertEqual(repo.number(), 2)
        repo.assert_clean()

    def test_amend_message_and_new_commit_reusing_message(self) -> None:
        repo = Repo(self)
        repo.change()
        repo.git("commit", "-qm", "ordinary")
        repo.change(content="amended\n")
        repo.git("commit", "--amend", "-qm", "replacement message")
        self.assertEqual(repo.git("log", "-1", "--format=%s"), "replacement message")
        self.assertEqual(repo.number(), 2)
        self.assertEqual(repo.count(), 2)
        repo.change(content="new commit\n")
        repo.git("commit", "-C", "HEAD", "-q")
        self.assertEqual(repo.git("log", "-1", "--format=%s"), "replacement message")
        self.assertEqual(repo.number(), 3)
        self.assertEqual(repo.count(), 3)
        repo.assert_clean()

    def test_automatic_merge_counts_only_first_parent(self) -> None:
        repo = Repo(self)
        repo.git("switch", "-qc", "feature")
        for index in range(3):
            repo.change(content=f"side {index}\n")
            repo.git("commit", "-qm", f"side {index}")
            self.assertEqual(repo.number(), 1)
        repo.git("switch", "-q", "main")
        merge = repo.run(["git", "merge", "--no-ff", "feature", "-m", "automatic merge"])
        self.assertEqual(len(repo.git("rev-list", "--parents", "-n1", "HEAD").split()), 3)
        self.assertEqual(
            repo.number(), 2, merge.stderr.decode("utf-8", errors="replace")
        )
        self.assertEqual(repo.count(), 2)
        self.assertEqual(repo.git("rev-list", "--count", "HEAD"), "5")
        repo.assert_clean()

    def test_feature_and_detached_match_ci_reachable_mainline(self) -> None:
        repo = Repo(self)
        base = repo.git("rev-parse", "HEAD")
        repo.change()
        repo.git("commit", "-qm", "main second")
        repo.git("update-ref", "refs/remotes/origin/main", "HEAD")
        repo.git("switch", "-qc", "feature", base)
        repo.change("branch.txt", "feature\n")
        repo.git("commit", "-qm", "feature")
        self.assertEqual(repo.number(), 1)
        repo.git("commit", "--amend", "-qm", "feature amend")
        self.assertEqual(repo.number(), 1)
        repo.git("switch", "-q", "--detach", base)
        repo.change("detached.txt", "detached\n")
        repo.git("commit", "-qm", "detached")
        self.assertEqual(repo.number(), 1)
        repo.assert_clean()

    def test_fast_forward_keeps_existing_merge_commit_unchanged(self) -> None:
        repo = Repo(self)
        repo.git("switch", "-qc", "upstream")
        repo.git("switch", "-qc", "topic")
        repo.change()
        repo.git("commit", "-qm", "topic")
        repo.git("switch", "-q", "upstream")
        repo.git("merge", "--no-ff", "topic", "-m", "existing upstream merge")
        existing = repo.git("rev-parse", "HEAD")
        tree = repo.git("rev-parse", "HEAD^{tree}")
        repo.git("switch", "-q", "main")
        # Its first parent is ORIG_HEAD even though this is a fast-forward.
        # MERGE_HEAD must distinguish this from a newly created merge.
        repo.git("merge", "--ff-only", "upstream")
        self.assertEqual(repo.git("rev-parse", "HEAD"), existing)
        self.assertEqual(repo.git("rev-parse", "HEAD^{tree}"), tree)
        self.assertEqual(repo.number(), 1)
        repo.assert_clean()

    def test_squash_merge_keeps_head_and_stages_changes(self) -> None:
        repo = Repo(self)
        repo.git("switch", "-qc", "topic")
        repo.change()
        repo.git("commit", "-qm", "topic")
        repo.git("switch", "-q", "main")
        original = repo.git("rev-parse", "HEAD")
        repo.git("merge", "--squash", "topic")
        self.assertEqual(repo.git("rev-parse", "HEAD"), original)
        self.assertEqual(repo.number(), 1)
        self.assertEqual(repo.git("diff", "--cached", "--name-only"), "notes.txt")
        repo.git("commit", "-qm", "squash commit")
        self.assertEqual(repo.number(), 2)
        self.assertEqual(repo.count(), 2)
        repo.assert_clean()

    def test_commit_only_is_refused_without_changing_pending_index(self) -> None:
        repo = Repo(self)
        repo.change("staged.txt", "keep staged\n")
        repo.write("notes.txt", "only this file\n")
        before = repo.snapshot()
        result = repo.run(["git", "commit", "--only", "notes.txt", "-qm", "only notes"], ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"temporary commit indexes", result.stderr)
        self.assertEqual(repo.snapshot(), before)
        self.assertEqual(repo.git("show", ":staged.txt"), "keep staged")
        self.assertNotEqual(repo.run(["git", "cat-file", "-e", "HEAD:staged.txt"], ok=False).returncode, 0)
        self.assertEqual(repo.git("diff", "--cached", "--name-only"), "staged.txt")
        self.assertEqual(repo.git("diff", "--name-only"), "notes.txt")

    def test_partially_staged_pubspec_refused_without_mutation(self) -> None:
        repo = Repo(self)
        repo.write("pubspec.yaml", "name: staged_name\nversion: 1.0.0+1\n")
        repo.git("add", "pubspec.yaml")
        repo.write("pubspec.yaml", "name: staged_name\nversion: 9.9.9+1\n# unstaged\n")
        before = repo.snapshot()
        result = repo.run(["git", "commit", "-m", "partial pubspec"], ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"unstaged changes", result.stderr)
        self.assertEqual(repo.snapshot(), before)

    def test_unstaged_pubspec_refused_without_mutation(self) -> None:
        repo = Repo(self)
        repo.change()
        repo.write("pubspec.yaml", "name: hook_test\nversion: 9.9.9+1\n")
        before = repo.snapshot()
        result = repo.run(["git", "commit", "-m", "dirty pubspec"], ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(repo.snapshot(), before)

    def test_partially_staged_dart_refused_without_mutation(self) -> None:
        repo = Repo(self)
        repo.change("file with spaces.dart", "void main(){print('staged');}\n")
        repo.write("file with spaces.dart", "void main(){print('unstaged');}\n")
        before = repo.snapshot()
        result = repo.run(["git", "commit", "-m", "partial Dart"], ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"unstaged changes", result.stderr)
        self.assertEqual(repo.snapshot(), before)

    def test_invalid_dart_refused_before_pubspec_mutation(self) -> None:
        repo = Repo(self)
        repo.change("file with spaces.dart", "void main( {\n")
        before = repo.snapshot()
        result = repo.run(["git", "commit", "-m", "bad Dart"], ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"dart format failed", result.stderr)
        self.assertEqual(repo.snapshot(), before)

    def test_signed_amend_stays_signed_and_keeps_message_author(self) -> None:
        repo = Repo(self, signed=True)
        repo.change()
        message = self.run_root / "large signed commit message.txt"
        message.write_text("signed ordinary\n\n" + "large message body\n" * 10000, encoding="utf-8")
        repo.git("commit", "-q", "-F", str(message))
        repo.assert_signature()
        before = repo.git("show", "-s", "--format=%an%n%ae%n%aI%n%B")
        repo.change(content="signed amend\n")
        repo.git("commit", "--amend", "--no-edit", "-q")
        self.assertEqual(repo.number(), 2)
        self.assertEqual(repo.count(), 2)
        self.assertEqual(repo.git("show", "-s", "--format=%an%n%ae%n%aI%n%B"), before)
        repo.assert_signature()
        repo.assert_clean()
        # An explicit -S also remains signed when commit.gpgsign is false.
        repo.git("config", "--local", "commit.gpgsign", "false")
        repo.change(content="explicit signature\n")
        repo.git("commit", "--amend", "--no-edit", "-qS")
        repo.assert_signature()
        repo.assert_clean()

    def test_unsigned_amend_does_not_start_signer(self) -> None:
        repo = Repo(self)
        repo.change()
        repo.git("commit", "-qm", "unsigned ordinary")
        repo.git("config", "--local", "commit.gpgsign", "true")
        repo.git("config", "--local", "gpg.ssh.program", "fzu-test-nonexistent-signer")
        repo.change(content="unsigned amend\n")
        repo.git("commit", "--amend", "--no-edit", "--no-gpg-sign", "-q")
        self.assertEqual(repo.number(), 2)
        repo.assert_signature(signed=False)
        repo.assert_clean()

    def test_correction_keeps_unrelated_staged_and_unstaged_data(self) -> None:
        repo = Repo(self)
        repo.change()
        repo.git("commit", "-qm", "ordinary")
        # post-commit normally runs after the index is committed. A tiny
        # post wrapper simulates another tool staging/editing files at this point.
        hook = repo.path / ".githooks/post-commit"
        original = hook.read_text(encoding="utf-8")
        hook.write_text(
            "#!/usr/bin/env bash\n"
            "if [[ -z \"${FZU_BUILD_NUMBER_REPAIR:-}\" ]]; then\n"
            "  printf 'staged by another tool\\n' > extra.txt\n"
            "  git add -- extra.txt\n"
            "  printf 'unstaged Dart\\n' > 'file with spaces.dart'\n"
            "fi\n"
            + original,
            encoding="utf-8",
            newline="\n",
        )
        repo.change(content="amend\n")
        repo.git("commit", "--amend", "--no-edit", "-q")
        self.assertEqual(repo.number(), 2)
        self.assertEqual(repo.git("show", ":extra.txt"), "staged by another tool")
        self.assertNotEqual(repo.run(["git", "cat-file", "-e", "HEAD:extra.txt"], ok=False).returncode, 0)
        self.assertEqual((repo.path / "file with spaces.dart").read_text(), "unstaged Dart\n")
        self.assertEqual(repo.git("show", "HEAD:file with spaces.dart"), "void main() {}")

    def test_post_refuses_dirty_pubspec_and_reports_existing_commit(self) -> None:
        repo = Repo(self)
        repo.change()
        repo.git("commit", "-qm", "ordinary")
        hook = repo.path / ".githooks/post-commit"
        original = hook.read_text(encoding="utf-8")
        hook.write_text(
            "#!/usr/bin/env bash\n"
            "printf '# added after pre-commit\\n' >> pubspec.yaml\n" + original,
            encoding="utf-8",
            newline="\n",
        )
        repo.change(content="amend\n")
        result = repo.run(["git", "commit", "--amend", "--no-edit", "-q"])
        # Git ignores post-commit's exit code: the error must say it exists.
        self.assertIn(b"the commit already exists", result.stderr)
        self.assertIn(b"correction FAILED", result.stderr)
        self.assertEqual(repo.number(), 3)  # The provisional commit is retained.
        self.assertEqual(repo.count(), 2)
        self.assertIn(b"# added after pre-commit", (repo.path / "pubspec.yaml").read_bytes())
        self.assertNotIn("# added after pre-commit", repo.git("show", ":pubspec.yaml"))

    def test_failed_correction_signing_keeps_signed_provisional_commit(self) -> None:
        repo = Repo(self, signed=True)
        repo.change()
        repo.git("commit", "-qm", "ordinary")
        # This signer permits the original amend but rejects its correction.
        signer = repo.path / "fail-correction-signer.sh"
        signer.write_text(
            "#!/usr/bin/env bash\n"
            "if [[ -n \"${FZU_BUILD_NUMBER_REPAIR:-}\" ]]; then\n"
            "  echo 'intentional signing failure' >&2\n"
            "  exit 1\n"
            "fi\n"
            f'exec "{SSH_KEYGEN.as_posix()}" "$@"\n',
            encoding="utf-8",
            newline="\n",
        )
        signer.chmod(0o755)
        repo.git("config", "--local", "gpg.ssh.program", signer.as_posix())
        repo.change(content="signature failure\n")
        result = repo.run(["git", "commit", "--amend", "--no-edit", "-q"])
        self.assertIn(b"intentional signing failure", result.stderr)
        self.assertIn(b"the commit already exists", result.stderr)
        self.assertEqual(repo.number(), 3)
        self.assertEqual(repo.count(), 2)
        repo.git("config", "--local", "gpg.ssh.program", SSH_KEYGEN.as_posix())
        repo.assert_signature()
        self.assertEqual(repo.git("show", "HEAD:notes.txt"), "signature failure")
        self.assertEqual(repo.git("diff", "--", "pubspec.yaml"), "")
        self.assertEqual(repo.git("diff", "--cached", "--", "pubspec.yaml"), "")

    def test_shallow_clone_is_explicitly_refused(self) -> None:
        source = Repo(self)
        source.change()
        source.git("commit", "-qm", "second")
        clone = self.run_root / "shallow clone with spaces"
        source.run(["git", "clone", "-q", "--depth=1", source.path.as_uri(), str(clone)])
        source.path = clone
        source.git("config", "--local", "user.name", "Hook Tests")
        source.git("config", "--local", "user.email", "hook-tests@example.invalid")
        source.git("config", "--local", "commit.gpgsign", "false")
        source.run([str(BASH), (PROJECT / "scripts/install-git-hooks.sh").as_posix()])
        source.change(content="shallow\n")
        before = source.snapshot()
        result = source.run(["git", "commit", "-m", "shallow"], ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"shallow clones are unsupported", result.stderr)
        self.assertEqual(source.snapshot(), before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
