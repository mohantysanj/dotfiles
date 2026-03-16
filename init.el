;;; init.el --- Minimal Emacs configuration -*- lexical-binding: t -*-

;;; Commentary:
;; A focused writing and research environment with Vertico completion,
;; Org-mode integration, NIH grant support, and Scrivener-style two-pane editing.
;;
;; Portable: Works on any machine with Emacs 28+
;; Dependencies installed automatically via use-package
;;
;; First-run notes:
;; - Packages are installed automatically on first launch (requires network)
;; - Run M-x nerd-icons-install-fonts once after initial setup for proper icons
;; - Customize my/org-directory and my/bibliography-file for your paths

;;; Code:

;;;; ============================================================
;;;;                    EARLY INIT / PERFORMANCE
;;;; ============================================================

;; Increase GC threshold during startup, reset after init
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)  ; 16MB
                  gc-cons-percentage 0.1)
            (message "Emacs ready in %.2f seconds with %d garbage collections."
                     (float-time (time-subtract after-init-time before-init-time))
                     gcs-done)))

;;;; ============================================================
;;;;                    PACKAGE MANAGEMENT
;;;; ============================================================

(require 'package)
;; package-archives is set in early-init.el so Emacs 27+ auto-initialization
;; uses MELPA.  package-initialize is omitted: it runs automatically before
;; init.el in Emacs 27+, and an explicit call causes a startup warning in 29+.

;; Defined before use so the refresh guard below can call it.
(defvar my/package-refreshed nil
  "Flag to avoid multiple refreshes in one session.")

(defun my/ensure-package-refresh ()
  "Refresh package contents once per session if needed."
  (unless my/package-refreshed
    (package-refresh-contents)
    (setq my/package-refreshed t)))

(unless (package-installed-p 'use-package)
  (my/ensure-package-refresh)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;;;; ============================================================
;;;;                    NATIVE COMPILATION
;;;; ============================================================

(when (and (fboundp 'native-comp-available-p)
           (native-comp-available-p))
  (setq native-comp-async-report-warnings-errors nil)
  (if (boundp 'native-comp-jit-compilation)
      (setq native-comp-jit-compilation t)
    (setq native-comp-deferred-compilation t)))

;;;; ============================================================
;;;;                    USER PATHS (CUSTOMIZE THESE)
;;;; ============================================================

(defgroup my/paths nil
  "User-specific paths for org files and bibliography."
  :group 'convenience
  :prefix "my/")

(defcustom my/org-directory "~/Sync/Documents/org"
  "Directory for org files. Change this to match your setup."
  :type 'directory
  :group 'my/paths)

(defcustom my/bibliography-file "~/Sync/Documents/bib/references.bib"
  "Path to bibliography file. Change this to match your setup."
  :type 'file
  :group 'my/paths)

(defcustom my/notes-directory "~/Sync/Documents/notes/"
  "Directory for Denote notes."
  :type 'directory
  :group 'my/paths)

;; Create org directory if it doesn't exist
(unless (file-exists-p my/org-directory)
  (make-directory my/org-directory t))

(unless (file-exists-p my/notes-directory)
  (make-directory my/notes-directory t))

;;;; ============================================================
;;;;                    UI: CLEAN VISUAL ENVIRONMENT
;;;; ============================================================

(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(setq inhibit-startup-screen t)
(setq-default line-spacing 0.2)
(global-visual-line-mode t)

;; Frame configuration — fullscreen applied after init to avoid WM race on width
(setq initial-frame-alist '((top . 1) (width . 85)))
(setq default-frame-alist '((top . 1) (width . 85)))

;; Center frame horizontally on the display
(defun my/center-frame (&optional frame)
  "Center FRAME (or current frame) horizontally on the display."
  (interactive)
  (let ((frame (or frame (selected-frame))))
    (when (display-graphic-p frame)
      (let* ((display-width (display-pixel-width))
             (frame-width (frame-pixel-width frame))
             (left (max 0 (/ (- display-width frame-width) 2))))
        (set-frame-parameter frame 'left left)))))

;; Typography - with fallbacks for portability
(defun my/set-fonts ()
  "Set fonts with fallbacks for different systems."
  (when (display-graphic-p)
    ;; Try preferred fonts, fall back to defaults
    (let ((preferred-fonts '("Inter" "SF Pro Text" "Helvetica Neue" "Arial" "DejaVu Sans")))
      (cl-loop for font in preferred-fonts
               when (member font (font-family-list))
               do (progn
                    (set-face-attribute 'default nil :family font :height 140)
                    (set-face-attribute 'variable-pitch nil :family font :height 1.0)
                    (cl-return))))
    ;; Fixed pitch - try common monospace fonts
    (let ((mono-fonts '("JetBrains Mono" "Fira Code" "Source Code Pro" "Consolas" "DejaVu Sans Mono" "Monospace")))
      (cl-loop for font in mono-fonts
               when (member font (font-family-list))
               do (progn
                    (set-face-attribute 'fixed-pitch nil :family font :height 1.0)
                    (cl-return))))))

;; Set fonts, center, and apply full height after init (daemon mode compatible).
;; fullscreen is applied here rather than in frame-alist to avoid a WM race
;; condition that could cause the initial frame to appear at the wrong width.
(if (daemonp)
    (add-hook 'after-make-frame-functions
              (lambda (frame)
                (with-selected-frame frame
                  (my/set-fonts)
                  (my/center-frame frame)
                  (set-frame-parameter frame 'fullscreen 'fullheight))))
  (add-hook 'after-init-hook #'my/set-fonts)
  (add-hook 'after-init-hook #'my/center-frame t)
  (add-hook 'after-init-hook
            (lambda () (set-frame-parameter nil 'fullscreen 'fullheight))))

;; Theme: modus-vivendi is built-in from Emacs 28+; install from MELPA on older versions
(if (>= emacs-major-version 28)
    (load-theme 'modus-vivendi :no-confirm)
  (unless (package-installed-p 'modus-themes)
    (my/ensure-package-refresh)
    (package-install 'modus-themes))
  (load-theme 'modus-vivendi :no-confirm))

;;;; ============================================================
;;;;                    COMPLETION FRAMEWORK
;;;; ============================================================

(use-package vertico
  :init (vertico-mode))

(use-package marginalia
  :init (marginalia-mode))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package consult
  :bind (("C-s" . consult-line)
         ("M-i" . consult-imenu)
         ("M-y" . consult-yank-pop)
         ("C-x b" . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window)
         ("C-x 5 b" . consult-buffer-other-frame)
         ("C-c r" . consult-ripgrep))
  :config
  (setq consult-preview-key 'any)
  ;; Narrow to subtree only after consult-imenu jumps, not all consult commands
  (advice-add 'consult-imenu :after
              (lambda (&rest _)
                (when (derived-mode-p 'org-mode)
                  (org-narrow-to-subtree)))))

(use-package embark
  :bind (("C-." . embark-act)))

(use-package embark-consult
  :after (embark consult))

(use-package which-key
  :init (which-key-mode))

(use-package nerd-icons-completion
  :after marginalia
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup)
  ;; Install Nerd Fonts on first use, deferred so it doesn't block startup
  (when (and (display-graphic-p)
             (not (find-font (font-spec :name "Symbols Nerd Font Mono"))))
    (run-with-idle-timer 2 nil (lambda () (nerd-icons-install-fonts t)))))

;;;; ============================================================
;;;;                    WRITING MODES
;;;; ============================================================

(use-package mixed-pitch
  :hook (org-mode . mixed-pitch-mode))

(use-package centered-cursor-mode
  :commands centered-cursor-mode)

(use-package wc-mode
  :commands wc-mode
  :config
  (setq-default wc-word-goal 200)
  (setq wc-modeline-format " Words [%W/%w] | Goal [%gw] "))

(use-package writeroom-mode
  :bind ("C-c z" . writeroom-mode)
  :config
  (setq writeroom-width 70
        writeroom-mode-line t)
  :hook
  ((writeroom-mode . mixed-pitch-mode)
   (writeroom-mode . centered-cursor-mode)
   (writeroom-mode . wc-mode)))

(use-package logos
  :after org
  :custom
  (logos-outlines-are-pages t)
  (logos-hide-mode-line t)
  (logos-hide-header-line t)
  (logos-variable-pitch t)
  :bind (("<f9>" . logos-focus-mode)
	 :map logos-focus-mode-map
	 ("<next>" . logos-forward-page-dwim)
	 ("<prior>" . logos-backward-page-dwim)))

;;;; ============================================================
;;;;                    ORG MODE
;;;; ============================================================

(use-package org
  :ensure nil  ;; Built-in; don't pull from ELPA (avoids version conflicts)
  :custom
  (org-todo-keywords '((sequence "TOREAD" "READING(r!)" "PAUSED(p@)" "ABORTED(a@)" "|" "DONE")))
  (org-directory my/org-directory)
  (org-agenda-files (list my/org-directory))
  (org-log-done t)
  (org-cite-global-bibliography (list my/bibliography-file))
  (org-cite-insert-processor 'citar)
  (org-cite-follow-processor 'citar)
  (org-cite-activate-processor 'citar)
  :bind (("C-c c" . org-capture)
         ("C-c a" . org-agenda)
         ("C-c l" . org-store-link))
  :config
  ;; Capture templates using the customizable path
  (setq org-capture-templates
        `(("j" "Journal" entry (file+datetree ,(expand-file-name "journal.org" my/org-directory))
           "* %?\n %U\n")
          ("n" "Note" entry (file+headline ,(expand-file-name "notes.org" my/org-directory) "Notes")
           "* %?\n %U\n")
          ("t" "Task" entry (file+headline ,(expand-file-name "tasks.org" my/org-directory) "Tasks")
           "* TODO %?\n %U\n")
          ("b" "Book" entry (file+headline ,(expand-file-name "booklist.org" my/org-directory) "Books")
           "** TOREAD %^{Title} / %^{Author} (%^{Year})\n  Notes: %?")))
)

;;;; ============================================================
;;;;                    RESEARCH & KNOWLEDGE MANAGEMENT
;;;; ============================================================

(use-package deft
  :commands deft
  :custom
  (deft-directory my/org-directory)
  (deft-use-filename-as-title t)
  (deft-recursive t))

(use-package denote
  :bind ("C-c n n" . denote)
  :custom
  (denote-directory my/notes-directory)
  (denote-known-keywords '("research" "books"))
  (denote-templates
   '((research . "* What it shows\n\n* For my work\n\n* Next action\n\n")
     (book     . "* Summary\n\n* Key ideas\n\n* How it changes my thinking\n\n"))))

(use-package consult-denote
  :after (consult denote)
  :bind
  (("C-c n f" . consult-denote-find)
   ("C-c n g" . consult-denote-grep))
  :config
  (consult-denote-mode 1))

(use-package citar
  :custom
  (citar-bibliography (list my/bibliography-file)))

(use-package citar-embark
  :after (citar embark)
  :no-require
  :config (citar-embark-mode))

(use-package citar-denote
  :after (citar denote)
  :config (citar-denote-mode))

(defun my/booklist-done-hook ()
  "When a book is marked DONE in booklist.org, create a Denote note linked back."
  (when (and (buffer-file-name)
             (string-match-p "booklist\\.org$" (buffer-file-name))
             (string= org-state "DONE"))
    (let* ((heading (org-get-heading t t t t))
           (title (replace-regexp-in-string " / .*$" "" heading))
           (note-title (read-string "Book note title: " title))
           ;; Capture file + heading text before buffer switch
           (src-file (buffer-file-name))
           (src-heading heading))
      (run-with-idle-timer
       0 nil
       (lambda ()
         (let ((path (denote note-title '("books") nil nil nil 'book)))
           (with-current-buffer (find-file-noselect path)
             (goto-char (point-min))
             (when (re-search-forward "^#\\+identifier:" nil t)
               (end-of-line)
               (insert "\n#+booklist-entry: [[file:" src-file "][" src-heading "]]"))
             (save-buffer))))))))

(add-hook 'org-after-todo-state-change-hook
          #'my/booklist-done-hook)

;;;; ============================================================
;;;;                    NIH GRANT SUPPORT
;;;; ============================================================

;; PDF viewing - graceful fallback if pdf-tools can't compile
(use-package pdf-tools
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :init
  (add-hook 'pdf-view-mode-hook
            (lambda () (display-line-numbers-mode -1)))
  :config
  (setq pdf-view-display-size 'fit-width)
  ;; Try to install, but don't error if it fails
  (unless (and (boundp 'pdf-info-epdfinfo-program)
               pdf-info-epdfinfo-program
               (file-executable-p pdf-info-epdfinfo-program))
    (condition-case nil
        (pdf-tools-install t)
      (error (message "pdf-tools: epdfinfo not available, using doc-view")))))

;; Load NIH grant setup after org
(with-eval-after-load 'org
  (let ((nih-file (expand-file-name "nih-grant-setup.el" user-emacs-directory)))
    (when (file-exists-p nih-file)
      (load nih-file t))))

;; Pandoc for DOCX export
(use-package ox-pandoc
  :after org)

;;;; ============================================================
;;;;                    SCRIVENER-STYLE TWO-PANE EDITING
;;;; ============================================================

(defgroup my/scrivener nil
  "Scrivener-style two-pane Org writing environment."
  :group 'org
  :prefix "my/scrivener-")

(defcustom my/scrivener-default-heading "Story"
  "Default heading to narrow to when entering Scrivener view."
  :type 'string
  :group 'my/scrivener)

(defcustom my/scrivener-binder-width 0.25
  "Width of the binder pane as a fraction of the frame."
  :type 'float
  :group 'my/scrivener)

(defcustom my/scrivener-sync-delay 0.15
  "Delay in seconds before syncing outline to prose pane."
  :type 'float
  :group 'my/scrivener)

(defvar my/scrivener-saved-window-config nil)
(defvar my/scrivener-sync-timer nil)
(defvar my/scrivener-prose-window nil)
(defvar my/scrivener-outline-window nil)
(defvar my/scrivener-binder-map nil)

;; Declare org functions for byte-compiler
(declare-function org-at-heading-p "org")
(declare-function org-get-heading "org")
(declare-function org-heading-components "org")
(declare-function org-narrow-to-subtree "org")
(declare-function org-fold-show-entry "org-fold")
(declare-function org-show-entry "org")
(declare-function org-next-visible-heading "org")
(declare-function org-previous-visible-heading "org")
(declare-function org-forward-heading-same-level "org")
(declare-function org-backward-heading-same-level "org")
(declare-function org-overview "org")
(declare-function org-content "org")
(declare-function outline-up-heading "outline")

(defun my/org-scrivener-sync ()
  "Project the heading under point from the Outline to the Prose pane."
  (interactive)
  (require 'org)
  (when (and (derived-mode-p 'org-mode)
             (org-at-heading-p)
             my/scrivener-prose-window
             (window-live-p my/scrivener-prose-window))
    (let* ((heading (org-get-heading t t t t))
           (level (car (org-heading-components))))
      (when heading
        (with-selected-window my/scrivener-prose-window
          (widen)
          (goto-char (point-min))
          (let ((search-re (concat "^" (make-string level ?*) " " (regexp-quote heading))))
            (when (re-search-forward search-re nil t)
              (org-narrow-to-subtree)
              (if (fboundp 'org-fold-show-entry)
                  (org-fold-show-entry)
                (with-no-warnings (org-show-entry)))
              (recenter-top-bottom 0)
              (unless (bound-and-true-p centered-cursor-mode)
                (centered-cursor-mode 1)))))))))

(defun my/org-scrivener-sync-debounced ()
  "Debounced version of sync to avoid excessive updates."
  (when my/scrivener-sync-timer
    (cancel-timer my/scrivener-sync-timer))
  (setq my/scrivener-sync-timer
        (run-with-idle-timer my/scrivener-sync-delay nil #'my/org-scrivener-sync)))

(defun my/scrivener-goto-heading ()
  "Navigate to heading under point and sync to prose pane."
  (interactive)
  (require 'org)
  (when (org-at-heading-p)
    (my/org-scrivener-sync)))

(defun my/scrivener-section-word-count ()
  "Show word count for current narrowed section."
  (interactive)
  (if (buffer-narrowed-p)
      (message "Section: %d words" (count-words (point-min) (point-max)))
    (message "Buffer is not narrowed to a section.")))

(defun my/scrivener-setup-binder-map ()
  "Initialize the binder keymap after org-mode is available."
  (require 'org)
  (unless my/scrivener-binder-map
    (setq my/scrivener-binder-map (make-sparse-keymap))
    (set-keymap-parent my/scrivener-binder-map org-mode-map)
    (define-key my/scrivener-binder-map (kbd "RET") #'my/scrivener-goto-heading)
    (define-key my/scrivener-binder-map (kbd "n") #'org-next-visible-heading)
    (define-key my/scrivener-binder-map (kbd "p") #'org-previous-visible-heading)
    (define-key my/scrivener-binder-map (kbd "u") #'outline-up-heading)
    (define-key my/scrivener-binder-map (kbd "f") #'org-forward-heading-same-level)
    (define-key my/scrivener-binder-map (kbd "b") #'org-backward-heading-same-level)
    (define-key my/scrivener-binder-map (kbd "w") #'my/scrivener-section-word-count))
  my/scrivener-binder-map)

(defun my/scrivener-enable ()
  "Enable Scrivener two-pane view."
  (require 'org)
  (unless (derived-mode-p 'org-mode)
    (user-error "Scrivener view only works in Org buffers"))
  (when (buffer-base-buffer)
    (user-error "Already in an indirect buffer"))

  (let ((base-name (buffer-name)))
    (setq my/scrivener-saved-window-config (current-window-configuration))
    (let* ((outline-buf (clone-indirect-buffer (concat base-name "-outline") nil))
           (prose-buf (clone-indirect-buffer (concat base-name "-prose") nil)))
      (delete-other-windows)
      (let* ((left-win (selected-window))
             (right-win (split-window-right
                         (truncate (* (window-total-width) my/scrivener-binder-width)))))
        (setq my/scrivener-outline-window left-win
              my/scrivener-prose-window right-win)

        ;; Setup binder (left)
        (set-window-buffer left-win outline-buf)
        (with-selected-window left-win
          (with-current-buffer outline-buf
            (org-overview)
            (org-content)
            (display-line-numbers-mode -1)
            (setq-local cursor-type 'bar)
            (setq-local mode-line-format '(" BINDER  " (:eval (abbreviate-file-name buffer-file-name))))
            (face-remap-add-relative 'default :height 0.9)
            (use-local-map (my/scrivener-setup-binder-map))
            (add-hook 'post-command-hook #'my/org-scrivener-sync-debounced nil t))
          (set-window-dedicated-p left-win t))

        ;; Setup prose (right)
        (select-window right-win)
        (set-window-buffer right-win prose-buf)
        (with-current-buffer prose-buf
          (setq-local writeroom-maximize-window nil)
          (setq-local writeroom-width 70)
          (writeroom-mode 1))

        ;; Initial heading
        (widen)
        (goto-char (point-min))
        (let ((heading-re (concat "^\\* " (regexp-quote my/scrivener-default-heading))))
          (if (re-search-forward heading-re nil t)
              (org-narrow-to-subtree)
            (message "Heading '* %s' not found." my/scrivener-default-heading)))

        (run-with-idle-timer 0.1 nil
                             (lambda ()
                               (when (window-live-p my/scrivener-prose-window)
                                 (with-selected-window my/scrivener-prose-window
                                   (centered-cursor-mode 1)))))
        (message "Scrivener view: n/p=navigate, RET=sync, w=word count")))))

(defun my/scrivener-disable ()
  "Disable Scrivener view and restore previous window configuration."
  (unless (or (and my/scrivener-outline-window
                   (window-live-p my/scrivener-outline-window))
              (and my/scrivener-prose-window
                   (window-live-p my/scrivener-prose-window)))
    (user-error "Not in Scrivener view"))
  (let* ((out-buf (and my/scrivener-outline-window
                       (window-live-p my/scrivener-outline-window)
                       (window-buffer my/scrivener-outline-window)))
         (pro-buf (and my/scrivener-prose-window
                       (window-live-p my/scrivener-prose-window)
                       (window-buffer my/scrivener-prose-window)))
         (base-name (and out-buf
                         (replace-regexp-in-string "-outline$" ""
                                                   (buffer-name out-buf))))
         (base-buf (and base-name (get-buffer base-name)))
         (saved-config my/scrivener-saved-window-config))
    (when my/scrivener-sync-timer
      (cancel-timer my/scrivener-sync-timer)
      (setq my/scrivener-sync-timer nil))
    (setq my/scrivener-outline-window nil
          my/scrivener-prose-window nil
          my/scrivener-saved-window-config nil)
    (when pro-buf
      (with-current-buffer pro-buf
        (when (bound-and-true-p writeroom-mode)
          (writeroom-mode -1))))
    (if saved-config
        (set-window-configuration saved-config)
      (delete-other-windows)
      (when base-buf (switch-to-buffer base-buf)))
    (when out-buf (kill-buffer out-buf))
    (when pro-buf (kill-buffer pro-buf))
    (when base-buf
      (with-current-buffer base-buf (widen)))
    (message "Exited Scrivener view.")))

(define-minor-mode my/scrivener-mode
  "Minor mode for Scrivener-style two-pane Org editing."
  :lighter " Scriv"
  :global t
  (if my/scrivener-mode
      (my/scrivener-enable)
    (my/scrivener-disable)))

(defun my/org-scrivener-view ()
  "Toggle Scrivener two-pane view."
  (interactive)
  (if (string-match-p "-outline$\\|-prose$" (buffer-name))
      (my/scrivener-mode -1)
    (my/scrivener-mode 1)))

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c s") #'my/org-scrivener-view))

;;;; ============================================================
;;;;                    CUSTOM FILE (KEEP SETTINGS SEPARATE)
;;;; ============================================================

;; Store customizations in a separate file
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file t))

;;; init.el ends here
