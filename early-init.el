;;; early-init.el --- Early initialization -*- lexical-binding: t -*-
;;
;; Runs before package-initialize and before frames are created.
;; Sets package-archives here so Emacs 27+ auto-initialization uses MELPA.
;; Without this, auto-init runs with the default gnu-only archive list.

(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("melpa"  . "https://melpa.org/packages/")
        ("stable" . "https://stable.melpa.org/packages/")))

;;; early-init.el ends here
